#!/usr/bin/env python3
"""
insightful-daemon.py - runs on HOST (outside Distrobox)

Monitors:
  1. Hyprland active window (title + class) via hyprctl
  2. Mouse movement via hyprctl cursorpos polling (100ms)
  3. Hyprland socket events (window/workspace switches)
  4. Creates a uinput virtual input device so tracker.node
     can read real kernel-level input events (needed for APM)

Writes to /dev/shm/insightful_state for the LD_PRELOAD hook.

SHM layout (must match insightful-proxy.c):
  int64_t last_activity  -- Unix timestamp of last activity
  int32_t idle_ms        -- reserved (0)
  int32_t force_window   -- always 1
  char    window_title[256]
  char    window_class[256]
Total: 528 bytes
"""
import fcntl, json, os, signal, struct, subprocess, sys, socket, threading, time

# ----------------------------------------------------------------
# Shared memory
# ----------------------------------------------------------------
SHM_PATH = "/dev/shm/insightful_state"

_last_activity = time.time()
_activity_lock = threading.Lock()
_shm_fd = -1       # opened once in run_daemon(), reused by write_shm()
running = True

def update_activity():
    global _last_activity
    with _activity_lock:
        _last_activity = time.time()

def get_last_activity():
    with _activity_lock:
        return _last_activity

def get_hyprland_window():
    try:
        r = subprocess.run(["hyprctl", "activewindow", "-j"],
                           capture_output=True, text=True, timeout=2)
        if r.returncode == 0 and r.stdout.strip():
            d = json.loads(r.stdout)
            if d and d.get("title"):
                return d.get("title","Desktop")[:200], d.get("class","Desktop")[:200]
    except Exception:
        pass
    return "Desktop", "Desktop"

def shm_open_once():
    """Open (or create) the SHM file once. Returns fd."""
    global _shm_fd
    if _shm_fd >= 0:
        return _shm_fd
    _shm_fd = os.open(SHM_PATH, os.O_CREAT | os.O_RDWR, 0o666)
    # Pre-fill 528 bytes so the mmap in the C hook has valid backing pages
    os.ftruncate(_shm_fd, 528)
    print(f"[SHM] opened fd={_shm_fd}", file=sys.stderr)
    return _shm_fd

def write_shm(title, cls, ts):
    """Write state to SHM in-place (seek to 0, no truncate).
    This preserves the mmap backing pages so the C hook's
    mmap pointer stays valid for the lifetime of the file."""
    try:
        fd = shm_open_once()
        tb = title.encode("utf-8","replace")[:255]
        cb = cls.encode("utf-8","replace")[:255]
        t256 = tb + b"\x00"*(256-len(tb))
        c256 = cb + b"\x00"*(256-len(cb))
        data = struct.pack("<qii256s256s", int(ts), 0, 1, t256, c256)
        os.lseek(fd, 0, os.SEEK_SET)
        os.write(fd, data)
    except Exception as e:
        print(f"[SHM] write error: {e}", file=sys.stderr)

# ----------------------------------------------------------------
# uinput virtual device
# ----------------------------------------------------------------
UINPUT_PATH   = "/dev/uinput"
UI_DEV_CREATE = 0x5501
UI_DEV_DESTROY= 0x5502
UI_SET_EVBIT  = 0x40045564
UI_SET_RELBIT = 0x40045566
UI_DEV_SETUP  = 0x405c5503
EV_SYN=0; EV_REL=2; REL_X=0

_uinput_fd = None
_uinput_lock = threading.Lock()

def uinput_open():
    global _uinput_fd
    try:
        fd = os.open(UINPUT_PATH, os.O_WRONLY | os.O_NONBLOCK)
        fcntl.ioctl(fd, UI_SET_EVBIT, EV_SYN)
        fcntl.ioctl(fd, UI_SET_EVBIT, EV_REL)
        fcntl.ioctl(fd, UI_SET_RELBIT, REL_X)
        name = b"insightful-virtual-mouse" + b"\x00"*56   # 80 bytes total
        setup = struct.pack("=HHHH80sI", 0x06, 0, 0, 1, name, 0)
        fcntl.ioctl(fd, UI_DEV_SETUP, setup)
        fcntl.ioctl(fd, UI_DEV_CREATE)
        _uinput_fd = fd
        print("[uinput] Virtual mouse created", file=sys.stderr)
        return True
    except Exception as e:
        print(f"[uinput] Cannot create device: {e}", file=sys.stderr)
        return False

def uinput_close():
    global _uinput_fd
    if _uinput_fd is not None:
        try:
            fcntl.ioctl(_uinput_fd, UI_DEV_DESTROY)
            os.close(_uinput_fd)
        except Exception:
            pass
        _uinput_fd = None

def uinput_inject():
    """Write a REL_X + SYN event to the virtual device."""
    with _uinput_lock:
        if _uinput_fd is None:
            return
        try:
            tv = int(time.time())
            # struct input_event: long tv_sec, long tv_usec, u16 type, u16 code, s32 value
            rel = struct.pack("=qqHHi", tv, 0, EV_REL, REL_X, 1)
            syn = struct.pack("=qqHHi", tv, 0, EV_SYN, 0,     0)
            os.write(_uinput_fd, rel)
            os.write(_uinput_fd, syn)
        except Exception as e:
            print(f"[uinput] inject error: {e}", file=sys.stderr)

# ----------------------------------------------------------------
# Activity monitors
# ----------------------------------------------------------------
# How long to keep injecting uinput events after last detected activity.
# Matches the tracker's idle_setting (120s) from the server config.
ACTIVE_TIMEOUT = 120

# Linux input event types we care about
EV_KEY_T = 1    # keyboard key / mouse button
EV_REL_T = 2    # mouse relative movement / scroll wheel

def evdev_monitor():
    """Read real /dev/input devices for keyboard, mouse buttons, and scroll.
    This detects ALL physical user input: key presses, mouse clicks,
    scroll wheel, and mouse movement via the kernel evdev interface.
    Runs on the HOST where we have the input group."""
    import select as sel
    fds = []
    fd_names = {}

    # Scan all input devices and open ones that support KEY or REL events
    for i in range(30):
        path = f"/dev/input/event{i}"
        if not os.path.exists(path):
            continue
        # Skip our own virtual device
        try:
            name_path = f"/sys/class/input/event{i}/device/name"
            if os.path.exists(name_path):
                dname = open(name_path).read().strip()
                if "insightful" in dname.lower():
                    continue
                # Skip audio/video/power devices (only want HID)
                if any(x in dname.lower() for x in ("hdmi", "audio", "video", "power", "mic", "headphone")):
                    continue
        except Exception:
            pass

        try:
            fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK)
            # Check if device supports EV_KEY or EV_REL using EVIOCGBIT
            import fcntl as fc
            buf = bytearray(8)
            EVIOCGBIT_0 = (2 << 30) | (ord("E") << 8) | 0x20 | (8 << 16)
            fc.ioctl(fd, EVIOCGBIT_0, buf)
            bits = struct.unpack("<Q", bytes(buf))[0]
            has_key = bool(bits & (1 << EV_KEY_T))
            has_rel = bool(bits & (1 << EV_REL_T))
            if has_key or has_rel:
                fds.append(fd)
                fd_names[fd] = path
            else:
                os.close(fd)
        except Exception:
            try: os.close(fd)
            except: pass

    if not fds:
        print("[evdev] No suitable input devices found", file=sys.stderr)
        return

    print(f"[evdev] Monitoring {len(fds)} devices: {list(fd_names.values())}", file=sys.stderr)

    while running:
        try:
            readable, _, _ = sel.select(fds, [], [], 1.0)
            for fd in readable:
                try:
                    while True:
                        data = os.read(fd, 72)  # up to 3 events at once
                        if len(data) < 24:
                            break
                        for off in range(0, len(data) - 23, 24):
                            chunk = data[off:off+24]
                            _, _, ev_type, _, _ = struct.unpack("=qqHHi", chunk)
                            if ev_type in (EV_KEY_T, EV_REL_T):
                                update_activity()
                                break  # one update per batch is enough
                except (BlockingIOError, OSError):
                    pass
        except Exception as e:
            print(f"[evdev] error: {e}", file=sys.stderr)
            time.sleep(1)

    for fd in fds:
        try: os.close(fd)
        except: pass

def cursor_monitor():
    """Poll hyprctl cursorpos every 100ms. Update activity on change.
    This is a FALLBACK for when evdev can't detect certain mouse movements
    (e.g. touchpad gestures routed through Wayland only)."""
    last_pos = None
    fails = 0
    print("[cursor] Starting...", file=sys.stderr)
    while running:
        try:
            r = subprocess.run(["hyprctl","cursorpos"],
                               capture_output=True, text=True, timeout=1)
            if r.returncode == 0:
                pos = r.stdout.strip()
                if pos and pos != last_pos:
                    if last_pos is not None:
                        update_activity()
                    last_pos = pos
                fails = 0
            time.sleep(0.5)  # slower polling since evdev is primary now
        except Exception as e:
            fails += 1
            if fails > 10:
                print(f"[cursor] error: {e}", file=sys.stderr)
                fails = 0
            time.sleep(1)

def swayidle_monitor():
    """Use swayidle (ext-idle-notify Wayland protocol) to detect
    when user resumes from idle. This catches ALL input types
    including keyboard, mouse clicks, and scroll - the only
    reliable method on Wayland since evdev is blocked."""
    import shutil
    swayidle_bin = shutil.which("swayidle")
    if not swayidle_bin:
        print("[swayidle] Not found, skipping", file=sys.stderr)
        return
    print("[swayidle] Starting idle monitor...", file=sys.stderr)
    while running:
        try:
            proc = subprocess.Popen(
                [swayidle_bin, "-w",
                 "timeout", "3", "echo idle",
                 "resume", "echo resume"],
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                text=True
            )
            while running and proc.poll() is None:
                line = proc.stdout.readline().strip()
                if line == "resume":
                    update_activity()
                elif line == "idle":
                    pass  # just note it, don't do anything
            proc.terminate()
        except Exception as e:
            print(f"[swayidle] error: {e}", file=sys.stderr)
            time.sleep(5)

def activity_injector():
    """Continuously inject uinput events while user is active.
    The main loop handles SHM writes with the effective timestamp."""
    print("[injector] Starting...", file=sys.stderr)
    while running:
        try:
            idle = time.time() - get_last_activity()
            if idle < ACTIVE_TIMEOUT:
                uinput_inject()
            time.sleep(0.5)
        except Exception:
            time.sleep(1)

def hyprland_events():
    """Listen for Hyprland compositor events (window switch, etc)."""
    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE","")
    if not sig:
        try:
            sig = os.listdir("/run/user/1000/hypr")[0]
        except Exception:
            print("[hypr] cannot find instance", file=sys.stderr)
            return
    sock_path = f"/run/user/1000/hypr/{sig}/.socket2.sock"
    if not os.path.exists(sock_path):
        print(f"[hypr] socket not found: {sock_path}", file=sys.stderr)
        return
    print(f"[hypr] listening on {sock_path}", file=sys.stderr)
    while running:
        try:
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
                s.connect(sock_path)
                s.settimeout(5.0)
                while running:
                    try:
                        raw = s.recv(4096)
                        if raw:
                            for ev in raw.decode("utf-8","ignore").split("\n"):
                                if any(k in ev for k in
                                       ("activewindow","fullscreen","workspace","focusedmon")):
                                    update_activity()
                                    uinput_inject()
                    except socket.timeout:
                        continue
                    except Exception:
                        break
        except Exception as e:
            if running:
                print(f"[hypr] error: {e}", file=sys.stderr)
            time.sleep(5)

# ----------------------------------------------------------------
# Main
# ----------------------------------------------------------------
def run_daemon():
    global running
    print("[insightful-daemon] Starting...", file=sys.stderr)

    uinput_open()

    for target in (evdev_monitor, cursor_monitor, hyprland_events,
                  swayidle_monitor, activity_injector):
        threading.Thread(target=target, daemon=True).start()

    def cleanup(sig=None, frame=None):
        global running, _shm_fd
        running = False
        print("[insightful-daemon] Shutting down...", file=sys.stderr)
        uinput_close()
        # Write a stale timestamp (epoch 0) so the C hook reports high
        # idle time, but do NOT unlink the file -- if Workpuls is still
        # running, its mmap must remain valid for a future daemon restart.
        try:
            if _shm_fd >= 0:
                data = struct.pack("<qii256s256s",
                    0, 0, 0,
                    b"\x00"*256,
                    b"\x00"*256)
                os.lseek(_shm_fd, 0, os.SEEK_SET)
                os.write(_shm_fd, data)
                os.close(_shm_fd)
                _shm_fd = -1
        except Exception:
            pass
        sys.exit(0)

    signal.signal(signal.SIGINT,  cleanup)
    signal.signal(signal.SIGTERM, cleanup)

    print(f"[insightful-daemon] SHM={SHM_PATH}", file=sys.stderr)

    while running:
        try:
            title, cls = get_hyprland_window()
            # Use the "effective" timestamp: if within ACTIVE_TIMEOUT
            # of last real activity, report current time (user active).
            # Otherwise report the actual last_activity (user idle).
            real_la = get_last_activity()
            idle = time.time() - real_la
            effective_ts = time.time() if idle < ACTIVE_TIMEOUT else real_la
            write_shm(title, cls, effective_ts)
        except Exception as e:
            print(f"[daemon] error: {e}", file=sys.stderr)
        time.sleep(0.5)

if __name__ == "__main__":
    run_daemon()
