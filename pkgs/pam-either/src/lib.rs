//! pam_either: runs several PAM services at once and succeeds as soon as one
//! of them does, so sudo takes a password or a fingerprint, whichever comes
//! first, instead of waiting for the reader to time out before asking.
//!
//! Written for dotnix after Florian Bernier's pam-race
//! (github.com/fbernier/pam-race), whose design this follows: each service
//! runs in a helper process (PAM modules aren't written to run side by side
//! in one), and when one wins while the host is blocked reading the password
//! from its terminal, a newline is pushed into that terminal (TIOCSTI) so
//! the read returns normally, rather than a thread being cancelled under it
//! as in pam-fprint-grosshack.
//!
//! ```text
//! auth [success=done ...] pam_either.so helper=/…/pam-either-helper [settle=MS] [confdir=DIR] [debug] SERVICE...
//! ```

pub mod arbiter;
pub mod pam;
pub mod proto;

use std::ffi::{c_char, c_int, c_void, CStr, CString};
use std::os::fd::{AsRawFd, FromRawFd, OwnedFd, RawFd};
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::ptr;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Condvar, Mutex};
use std::time::{Duration, Instant};

use arbiter::{Action, Arbiter};
use proto::{FromHelper, ToHelper, MAX_PACKET};

/// What the module arguments say.
#[derive(Debug, PartialEq, Eq)]
pub struct Config {
    pub services: Vec<String>,
    pub helper: String,
    pub settle: Duration,
    pub confdir: String,
    pub debug: bool,
}

fn plain_name(s: &str) -> bool {
    !s.is_empty()
        && s.len() <= 255
        && s.bytes()
            .all(|b| b.is_ascii_alphanumeric() || b"._-".contains(&b))
}

impl Config {
    pub fn parse<'a>(args: impl IntoIterator<Item = &'a str>) -> Result<Config, String> {
        let mut c = Config {
            services: Vec::new(),
            helper: String::new(),
            settle: Duration::from_millis(600),
            confdir: String::new(),
            debug: false,
        };
        for arg in args {
            if arg == "debug" {
                c.debug = true;
            } else if let Some(v) = arg.strip_prefix("helper=") {
                c.helper = v.to_string();
            } else if let Some(v) = arg.strip_prefix("confdir=") {
                c.confdir = v.to_string();
            } else if let Some(v) = arg.strip_prefix("settle=") {
                let ms: u64 = v.parse().map_err(|_| format!("bad settle: {v}"))?;
                if ms > 5000 {
                    return Err(format!("settle above 5000 ms: {ms}"));
                }
                c.settle = Duration::from_millis(ms);
            } else if plain_name(arg) {
                if c.services.iter().any(|s| s == arg) {
                    return Err(format!("service given twice: {arg}"));
                }
                c.services.push(arg.to_string());
            } else {
                return Err(format!("unknown argument: {arg}"));
            }
        }
        if !c.helper.starts_with('/') {
            return Err("helper= must be an absolute path".into());
        }
        if !c.confdir.is_empty() && !c.confdir.starts_with('/') {
            return Err("confdir= must be an absolute path".into());
        }
        if c.services.is_empty() {
            return Err("no services".into());
        }
        Ok(c)
    }
}

fn log(debug: bool, msg: &str) {
    if !debug {
        return;
    }
    if let Ok(c) = CString::new(format!("pam_either: {msg}")) {
        unsafe {
            libc::syslog(
                libc::LOG_AUTHPRIV | libc::LOG_DEBUG,
                c"%s".as_ptr(),
                c.as_ptr(),
            )
        };
    }
}

/// One running helper.
struct Helper {
    pid: libc::pid_t,
    sock: OwnedFd,
}

impl Helper {
    fn send(&self, msg: &ToHelper) {
        let mut packet = msg.encode();
        unsafe {
            libc::send(
                self.sock.as_raw_fd(),
                packet.as_ptr().cast(),
                packet.len(),
                libc::MSG_NOSIGNAL,
            )
        };
        packet.fill(0);
    }
}

impl Drop for Helper {
    fn drop(&mut self) {
        // its own process group (setsid): whatever a module started goes too
        unsafe {
            libc::kill(-self.pid, libc::SIGKILL);
            libc::kill(self.pid, libc::SIGKILL);
            libc::waitpid(self.pid, ptr::null_mut(), 0);
        }
    }
}

/// The helper's environment: a plain PATH and the locale, nothing else.
fn helper_env() -> Vec<CString> {
    let mut env = vec![];
    for name in [
        "PATH",
        "LANG",
        "LANGUAGE",
        "LC_ALL",
        "LC_MESSAGES",
        "LC_CTYPE",
    ] {
        if let Ok(v) = std::env::var(name) {
            let ok = if name == "PATH" {
                v.split(':').all(|p| p.starts_with('/'))
            } else {
                v.is_ascii() && !v.contains('/') && !v.starts_with('.')
            };
            if ok {
                if let Ok(c) = CString::new(format!("{name}={v}")) {
                    env.push(c);
                }
            }
        }
    }
    env
}

/// fork+exec the helper with the socket on fd 3, no terminal, stdio on
/// /dev/null. Everything the child touches is prepared before the fork, and
/// the child only makes async-signal-safe calls.
fn spawn(helper: &CStr, env: &[CString]) -> Option<Helper> {
    let mut fds: [c_int; 2] = [-1, -1];
    if unsafe {
        libc::socketpair(
            libc::AF_UNIX,
            libc::SOCK_SEQPACKET | libc::SOCK_CLOEXEC,
            0,
            fds.as_mut_ptr(),
        )
    } != 0
    {
        return None;
    }
    let (ours, theirs) = unsafe { (OwnedFd::from_raw_fd(fds[0]), OwnedFd::from_raw_fd(fds[1])) };
    let argv: [*const c_char; 2] = [helper.as_ptr(), ptr::null()];
    let mut envp: Vec<*const c_char> = env.iter().map(|e| e.as_ptr()).collect();
    envp.push(ptr::null());
    let theirs_fd = theirs.as_raw_fd();
    let mut empty: libc::sigset_t = unsafe { std::mem::zeroed() };
    unsafe { libc::sigemptyset(&mut empty) };
    let mut default: libc::sigaction = unsafe { std::mem::zeroed() };
    default.sa_sigaction = libc::SIG_DFL;

    let pid = unsafe { libc::fork() };
    if pid < 0 {
        return None;
    }
    if pid == 0 {
        unsafe {
            libc::setsid();
            if theirs_fd == 3 {
                libc::fcntl(3, libc::F_SETFD, 0);
            } else if libc::dup2(theirs_fd, 3) != 3 {
                libc::_exit(127);
            }
            let null = libc::open(c"/dev/null".as_ptr(), libc::O_RDWR);
            if null < 0
                || libc::dup2(null, 0) < 0
                || libc::dup2(null, 1) < 0
                || libc::dup2(null, 2) < 0
            {
                libc::_exit(127);
            }
            libc::syscall(libc::SYS_close_range, 4u32, u32::MAX, 0u32);
            libc::prctl(libc::PR_SET_PDEATHSIG, libc::SIGKILL, 0, 0, 0);
            for sig in 1..65 {
                if sig != libc::SIGKILL && sig != libc::SIGSTOP {
                    libc::sigaction(sig, &default, ptr::null_mut());
                }
            }
            libc::sigprocmask(libc::SIG_SETMASK, &empty, ptr::null_mut());
            libc::execve(helper.as_ptr(), argv.as_ptr(), envp.as_ptr());
            libc::_exit(127);
        }
    }
    drop(theirs);
    Some(Helper { pid, sock: ours })
}

/// The host's terminal, while the host is its foreground (it is the one
/// reading the password then, not a shell or a pager).
fn foreground_tty() -> Option<OwnedFd> {
    let fd = unsafe {
        libc::open(
            c"/dev/tty".as_ptr(),
            libc::O_RDWR | libc::O_NOCTTY | libc::O_CLOEXEC,
        )
    };
    if fd < 0 {
        return None;
    }
    let fd = unsafe { OwnedFd::from_raw_fd(fd) };
    (unsafe { libc::tcgetpgrp(fd.as_raw_fd()) } == unsafe { libc::getpgrp() }).then_some(fd)
}

/// Ends the line the host is blocked reading: its read() returns as if the
/// user pressed Enter, and the answer is then discarded.
fn push_newline() -> bool {
    let Some(tty) = foreground_tty() else {
        return false;
    };
    let mut queued: c_int = 0;
    unsafe { libc::ioctl(tty.as_raw_fd(), libc::FIONREAD, &mut queued) };
    if queued > 0 {
        // a newline already waits there; another would reach the shell
        return true;
    }
    let nl: c_char = b'\n' as c_char;
    unsafe { libc::ioctl(tty.as_raw_fd(), libc::TIOCSTI, &nl) == 0 }
}

/// Drops what's left in the terminal's input after a released prompt.
fn flush_input() {
    if let Some(tty) = foreground_tty() {
        unsafe { libc::tcflush(tty.as_raw_fd(), libc::TCIFLUSH) };
    }
}

/// The host's conversation, one message at a time. Prompts return the
/// answer; `None` when the conversation failed (^C, EOF, sudo -n).
fn converse(conv: &pam::Conv, style: c_int, text: &str) -> Option<Vec<u8>> {
    let f = conv.conv?;
    let text = CString::new(text.replace('\0', "")).ok()?;
    let msg = pam::Message {
        style,
        msg: text.as_ptr(),
    };
    let mut msg_ptr: *const pam::Message = &msg;
    let mut resp: *mut pam::Response = ptr::null_mut();
    let rc = unsafe { f(1, &mut msg_ptr, &mut resp, conv.appdata) };
    let mut answer = None;
    if !resp.is_null() {
        unsafe {
            let r = (*resp).resp;
            if !r.is_null() {
                let bytes = CStr::from_ptr(r).to_bytes();
                answer = Some(bytes.to_vec());
                libc::explicit_bzero(r.cast(), bytes.len());
                libc::free(r.cast());
            }
            libc::free(resp.cast());
        }
    }
    if rc != pam::SUCCESS {
        if let Some(a) = answer.as_mut() {
            a.fill(0);
        }
        return None;
    }
    Some(answer.unwrap_or_default())
}

struct Shared {
    arbiter: Mutex<Arbiter>,
    changed: Condvar,
    stop: AtomicBool,
}

/// Reads the helpers' sockets into the arbiter, and releases the host's
/// prompt once the race is decided while it waits on it.
fn watch(shared: &Shared, socks: &[RawFd], debug: bool) {
    let mut open: Vec<bool> = vec![true; socks.len()];
    let mut pushes = 0;
    let mut buf = vec![0u8; MAX_PACKET];
    while !shared.stop.load(Ordering::SeqCst) {
        {
            let a = shared.arbiter.lock().unwrap();
            if a.must_release() {
                drop(a);
                // up to 6 newlines over ~1.3 s, should the first be read by
                // something else
                if pushes < 6 && push_newline() {
                    pushes += 1;
                    log(debug, "released the host's prompt");
                }
            }
        }
        let mut pfds: Vec<libc::pollfd> = socks
            .iter()
            .zip(&open)
            .filter(|(_, &o)| o)
            .map(|(&fd, _)| libc::pollfd {
                fd,
                events: libc::POLLIN,
                revents: 0,
            })
            .collect();
        if pfds.is_empty() {
            let a = shared.arbiter.lock().unwrap();
            if !a.must_release() {
                return;
            }
            drop(a);
            std::thread::sleep(Duration::from_millis(220));
            continue;
        }
        let n = unsafe { libc::poll(pfds.as_mut_ptr(), pfds.len() as libc::nfds_t, 220) };
        if n <= 0 {
            continue;
        }
        for p in &pfds {
            if p.revents == 0 {
                continue;
            }
            let i = socks.iter().position(|&s| s == p.fd).unwrap();
            let got = unsafe {
                libc::recv(
                    p.fd,
                    buf.as_mut_ptr().cast(),
                    buf.len(),
                    libc::MSG_TRUNC | libc::MSG_DONTWAIT,
                )
            };
            let msg = if got > 0 && (got as usize) <= buf.len() {
                FromHelper::decode(&buf[..got as usize])
            } else {
                None
            };
            let mut a = shared.arbiter.lock().unwrap();
            match msg {
                Some(FromHelper::Message { style, text }) => a.message(i, style as i32, text),
                Some(FromHelper::Done(rc)) => {
                    log(debug, &format!("helper {i} done: {rc}"));
                    a.done(i, Some(rc));
                    open[i] = false;
                }
                None => {
                    if got < 0 && unsafe { *libc::__errno_location() } == libc::EAGAIN {
                        continue;
                    }
                    log(debug, &format!("helper {i} gone"));
                    a.done(i, None);
                    open[i] = false;
                }
            }
            shared.changed.notify_all();
        }
        buf.fill(0);
    }
}

fn get_item(pamh: *mut pam::Handle, item: c_int) -> String {
    let mut out: *const c_void = ptr::null();
    if unsafe { pam::pam_get_item(pamh, item, &mut out) } != pam::SUCCESS || out.is_null() {
        return String::new();
    }
    unsafe { CStr::from_ptr(out.cast()) }
        .to_string_lossy()
        .into_owned()
}

fn authenticate(pamh: *mut pam::Handle, cfg: &Config) -> c_int {
    if std::env::var_os("PAM_EITHER_NESTED").is_some() {
        return pam::SERVICE_ERR;
    }
    let mut user_ptr: *const c_char = ptr::null();
    if unsafe { pam::pam_get_user(pamh, &mut user_ptr, ptr::null()) } != pam::SUCCESS
        || user_ptr.is_null()
    {
        return pam::SERVICE_ERR;
    }
    let user = unsafe { CStr::from_ptr(user_ptr) }
        .to_string_lossy()
        .into_owned();
    let mut conv_ptr: *const c_void = ptr::null();
    if unsafe { pam::pam_get_item(pamh, pam::ITEM_CONV, &mut conv_ptr) } != pam::SUCCESS
        || conv_ptr.is_null()
    {
        return pam::SERVICE_ERR;
    }
    let conv = unsafe { &*(conv_ptr as *const pam::Conv) };
    let (tty, rhost, ruser) = (
        get_item(pamh, pam::ITEM_TTY),
        get_item(pamh, pam::ITEM_RHOST),
        get_item(pamh, pam::ITEM_RUSER),
    );

    let Ok(helper) = CString::new(cfg.helper.as_str()) else {
        return pam::SERVICE_ERR;
    };
    let env = helper_env();
    let mut helpers = Vec::new();
    for service in &cfg.services {
        let Some(h) = spawn(&helper, &env) else {
            log(cfg.debug, "could not start a helper");
            return pam::SYSTEM_ERR;
        };
        h.send(&ToHelper::Setup {
            service: service.clone(),
            user: user.clone(),
            tty: tty.clone(),
            rhost: rhost.clone(),
            ruser: ruser.clone(),
            confdir: cfg.confdir.clone(),
        });
        helpers.push(h);
    }
    let socks: Vec<RawFd> = helpers.iter().map(|h| h.sock.as_raw_fd()).collect();
    let shared = Arc::new(Shared {
        arbiter: Mutex::new(Arbiter::new(helpers.len())),
        changed: Condvar::new(),
        stop: AtomicBool::new(false),
    });

    // the watcher must not take the host's signals (^C interrupts the
    // host's own read)
    let mut all: libc::sigset_t = unsafe { std::mem::zeroed() };
    let mut old: libc::sigset_t = unsafe { std::mem::zeroed() };
    unsafe {
        libc::sigfillset(&mut all);
        libc::pthread_sigmask(libc::SIG_SETMASK, &all, &mut old);
    }
    let watcher = {
        let shared = Arc::clone(&shared);
        let debug = cfg.debug;
        std::thread::spawn(move || watch(&shared, &socks, debug))
    };
    unsafe { libc::pthread_sigmask(libc::SIG_SETMASK, &old, ptr::null_mut()) };

    let deadline = Instant::now() + cfg.settle;
    let rc = loop {
        let mut a = shared.arbiter.lock().unwrap();
        match a.next(Instant::now() >= deadline) {
            Action::Decided(rc) => break rc,
            Action::Show { style, text, .. } => {
                drop(a);
                converse(conv, style, &text);
            }
            Action::Ask {
                helper,
                style,
                text,
            } => {
                drop(a);
                let answer = converse(conv, style, &text);
                let mut a = shared.arbiter.lock().unwrap();
                match answer {
                    None => {
                        a.cancelled();
                        helpers[helper].send(&ToHelper::Cancel);
                    }
                    Some(mut answer) => {
                        if a.answered(helper) {
                            helpers[helper].send(&ToHelper::Reply(answer.clone()));
                        } else {
                            // released by the watcher: drop the half-typed line
                            flush_input();
                        }
                        answer.fill(0);
                    }
                }
                shared.changed.notify_all();
            }
            Action::Wait => {
                let wait = deadline
                    .saturating_duration_since(Instant::now())
                    .max(Duration::from_millis(50));
                let _ = shared
                    .changed
                    .wait_timeout(a, wait.min(Duration::from_millis(250)))
                    .unwrap();
            }
        }
    };
    shared.stop.store(true, Ordering::SeqCst);
    let _ = watcher.join();
    drop(helpers);
    log(cfg.debug, &format!("race decided: {rc}"));
    rc
}

fn args(argc: c_int, argv: *const *const c_char) -> Vec<String> {
    (0..argc.max(0) as usize)
        .filter_map(|i| {
            let p = unsafe { *argv.add(i) };
            (!p.is_null()).then(|| unsafe { CStr::from_ptr(p) }.to_string_lossy().into_owned())
        })
        .collect()
}

/// # Safety
/// Called by libpam with a valid handle and argument vector.
#[no_mangle]
pub unsafe extern "C" fn pam_sm_authenticate(
    pamh: *mut pam::Handle,
    _flags: c_int,
    argc: c_int,
    argv: *const *const c_char,
) -> c_int {
    // a panic must not unwind into the host: it fails the module, and the
    // stack's control field falls back to the password
    catch_unwind(AssertUnwindSafe(|| {
        let args = args(argc, argv);
        match Config::parse(args.iter().map(String::as_str)) {
            Ok(cfg) => authenticate(pamh, &cfg),
            Err(e) => {
                log(true, &format!("configuration: {e}"));
                pam::SERVICE_ERR
            }
        }
    }))
    .unwrap_or(pam::SYSTEM_ERR)
}

/// # Safety
/// Called by libpam; sub-services only authenticate.
#[no_mangle]
pub unsafe extern "C" fn pam_sm_setcred(
    _pamh: *mut pam::Handle,
    _flags: c_int,
    _argc: c_int,
    _argv: *const *const c_char,
) -> c_int {
    pam::SUCCESS
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_arguments() {
        let c = Config::parse([
            "helper=/h",
            "settle=300",
            "debug",
            "sudo-fprint",
            "sudo-password",
        ])
        .unwrap();
        assert_eq!(c.services, vec!["sudo-fprint", "sudo-password"]);
        assert_eq!(c.settle, Duration::from_millis(300));
        assert!(c.debug);
        assert_eq!(c.helper, "/h");
    }

    #[test]
    fn rejects_bad_arguments() {
        assert!(Config::parse(["sudo-fprint"]).is_err(), "no helper");
        assert!(Config::parse(["helper=h", "a"]).is_err(), "relative helper");
        assert!(Config::parse(["helper=/h"]).is_err(), "no services");
        assert!(
            Config::parse(["helper=/h", "a", "a"]).is_err(),
            "service twice"
        );
        assert!(
            Config::parse(["helper=/h", "../etc/x"]).is_err(),
            "not a plain name"
        );
        assert!(Config::parse(["helper=/h", "settle=9000", "a"]).is_err());
        assert!(Config::parse(["helper=/h", "confdir=x", "a"]).is_err());
    }
}
