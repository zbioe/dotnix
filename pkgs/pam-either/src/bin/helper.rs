//! pam-either-helper: runs one PAM service's auth stack for the module, in
//! a process of its own (PAM modules aren't written to run side by side in
//! one process). The module started it with the socket on fd 3, no
//! terminal, and a minimal environment; it reads the setup, authenticates,
//! and relays every PAM message over the socket.

use std::ffi::{c_int, c_void, CStr, CString};
use std::ptr;

use pam_either::pam;
use pam_either::proto::{FromHelper, ToHelper, MAX_PACKET};

const SOCKET: c_int = 3;

fn send(msg: &FromHelper) -> bool {
    let packet = msg.encode();
    let n = unsafe {
        libc::send(
            SOCKET,
            packet.as_ptr().cast(),
            packet.len(),
            libc::MSG_NOSIGNAL,
        )
    };
    n == packet.len() as isize
}

fn recv() -> Option<ToHelper> {
    let mut buf = vec![0u8; MAX_PACKET];
    let n = unsafe { libc::recv(SOCKET, buf.as_mut_ptr().cast(), buf.len(), libc::MSG_TRUNC) };
    if n <= 0 || n as usize > buf.len() {
        return None;
    }
    buf.truncate(n as usize);
    let msg = ToHelper::decode(&buf);
    buf.fill(0);
    msg
}

/// Frees `count` responses libpam would otherwise have taken.
unsafe fn free_responses(resp: *mut pam::Response, count: usize) {
    for i in 0..count {
        let r = resp.add(i);
        if !(*r).resp.is_null() {
            let len = libc::strlen((*r).resp);
            libc::explicit_bzero((*r).resp.cast(), len);
            libc::free((*r).resp.cast());
        }
    }
    libc::free(resp.cast());
}

/// The service's conversation: each message goes to the module; a prompt
/// waits for its answer (or a cancel, which fails the conversation).
unsafe extern "C" fn conversation(
    num: c_int,
    msgs: *mut *const pam::Message,
    out: *mut *mut pam::Response,
    _appdata: *mut c_void,
) -> c_int {
    if num <= 0 || num > 32 || msgs.is_null() || out.is_null() {
        return pam::CONV_ERR;
    }
    let count = num as usize;
    let resp = libc::calloc(count, std::mem::size_of::<pam::Response>()) as *mut pam::Response;
    if resp.is_null() {
        return pam::CONV_ERR;
    }
    for i in 0..count {
        // Linux-PAM passes an array of pointers to messages
        let m = *msgs.add(i);
        if m.is_null() {
            free_responses(resp, i);
            return pam::CONV_ERR;
        }
        let style = (*m).style;
        let text = if (*m).msg.is_null() {
            String::new()
        } else {
            CStr::from_ptr((*m).msg).to_string_lossy().into_owned()
        };
        if !(1..=4).contains(&style)
            || !send(&FromHelper::Message {
                style: style as u8,
                text,
            })
        {
            free_responses(resp, i);
            return pam::CONV_ERR;
        }
        if style == pam::PROMPT_ECHO_OFF || style == pam::PROMPT_ECHO_ON {
            match recv() {
                Some(ToHelper::Reply(mut answer)) => {
                    answer.push(0);
                    let copy = libc::malloc(answer.len()) as *mut u8;
                    if copy.is_null() {
                        libc::explicit_bzero(answer.as_mut_ptr().cast(), answer.len());
                        free_responses(resp, i);
                        return pam::CONV_ERR;
                    }
                    ptr::copy_nonoverlapping(answer.as_ptr(), copy, answer.len());
                    libc::explicit_bzero(answer.as_mut_ptr().cast(), answer.len());
                    (*resp.add(i)).resp = copy.cast();
                }
                _ => {
                    free_responses(resp, i);
                    return pam::CONV_ERR;
                }
            }
        }
    }
    *out = resp;
    pam::SUCCESS
}

fn cstring(s: &str) -> Option<CString> {
    CString::new(s).ok()
}

fn authenticate() -> i32 {
    let Some(ToHelper::Setup {
        service,
        user,
        tty,
        rhost,
        ruser,
        confdir,
    }) = recv()
    else {
        return pam::SYSTEM_ERR;
    };
    let (Some(c_service), Some(c_user)) = (cstring(&service), cstring(&user)) else {
        return pam::SYSTEM_ERR;
    };
    let c_confdir = if confdir.is_empty() {
        None
    } else {
        cstring(&confdir)
    };
    let conv = pam::Conv {
        conv: Some(conversation),
        appdata: ptr::null_mut(),
    };
    let mut handle: *mut pam::Handle = ptr::null_mut();
    let rc = unsafe {
        pam::pam_start_confdir(
            c_service.as_ptr(),
            c_user.as_ptr(),
            &conv,
            c_confdir.as_ref().map_or(ptr::null(), |c| c.as_ptr()),
            &mut handle,
        )
    };
    if rc != pam::SUCCESS || handle.is_null() {
        return pam::SERVICE_ERR;
    }
    // where the request comes from, as the outer handle has it
    for (item, value) in [
        (pam::ITEM_TTY, &tty),
        (pam::ITEM_RHOST, &rhost),
        (pam::ITEM_RUSER, &ruser),
    ] {
        if value.is_empty() {
            continue;
        }
        let Some(c) = cstring(value) else {
            unsafe { pam::pam_end(handle, pam::SYSTEM_ERR) };
            return pam::SYSTEM_ERR;
        };
        if unsafe { pam::pam_set_item(handle, item, c.as_ptr().cast()) } != pam::SUCCESS {
            unsafe { pam::pam_end(handle, pam::SYSTEM_ERR) };
            return pam::SYSTEM_ERR;
        }
    }
    let mut rc = unsafe { pam::pam_authenticate(handle, 0) };
    if rc == pam::SUCCESS {
        // a stack that mapped the name authenticated someone else
        let mut item: *const c_void = ptr::null();
        let same = unsafe { pam::pam_get_item(handle, pam::ITEM_USER, &mut item) } == pam::SUCCESS
            && !item.is_null()
            && unsafe { CStr::from_ptr(item.cast()) }.to_bytes() == user.as_bytes();
        if !same {
            rc = pam::AUTH_ERR;
        }
    }
    unsafe { pam::pam_end(handle, rc) };
    rc
}

fn main() {
    unsafe {
        // it holds passwords: no core dumps, no ptrace by the invoking user
        libc::prctl(libc::PR_SET_DUMPABLE, 0, 0, 0, 0);
        // modules' messages in the user's language, as in an application
        libc::setlocale(libc::LC_ALL, c"".as_ptr());
        // nothing a module starts inherits the socket
        libc::fcntl(SOCKET, libc::F_SETFD, libc::FD_CLOEXEC);
    }
    // a sub-service that includes pam_either again finds it and declines
    std::env::set_var("PAM_EITHER_NESTED", "1");
    let rc = authenticate();
    send(&FromHelper::Done(rc));
}
