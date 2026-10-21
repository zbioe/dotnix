# answer.py PROMPT CMD...: runs CMD on a terminal and types stdin's first line after PROMPT
import os, pty, select, sys, time
prompt, cmd = sys.argv[1].encode(), sys.argv[2:]
secret = sys.stdin.readline()
pid, fd = pty.fork()
if pid == 0:
    os.execvp(cmd[0], cmd)
out, sent, deadline = b"", False, time.time() + 30
while time.time() < deadline:
    ready, _, _ = select.select([fd], [], [], 0.2)
    if ready:
        try:
            chunk = os.read(fd, 4096)
        except OSError:
            break
        if not chunk:
            break
        out += chunk
        if not sent and prompt in out:
            time.sleep(0.1)
            os.write(fd, secret.encode())
            sent = True
    elif sent and os.waitpid(pid, os.WNOHANG)[0]:
        break
_, status = os.waitpid(pid, 0)
sys.stdout.buffer.write(out.split(prompt, 1)[-1] if sent else out)
sys.exit(os.waitstatus_to_exitcode(status))
