import os
import pty
import select
import signal
import sys
import tempfile
import time
from pathlib import Path


def run_in_tty(path: str) -> str:
    pid, fd = pty.fork()
    if pid == 0:
        env = os.environ.copy()
        env["PATH"] = path
        env["TERM"] = "xterm"
        os.execvpe("pi", ["pi"], env)

    output = bytearray()
    deadline = time.monotonic() + 3
    while time.monotonic() < deadline:
        ready, _, _ = select.select([fd], [], [], 0.1)
        if ready:
            try:
                output.extend(os.read(fd, 65536))
            except OSError:
                break
        finished, _ = os.waitpid(pid, os.WNOHANG)
        if finished:
            break
    else:
        os.kill(pid, signal.SIGTERM)
        os.waitpid(pid, 0)
        raise AssertionError("bare pi did not dispatch within three seconds")
    return output.decode(errors="replace")


def main() -> None:
    launcher = Path(sys.argv[1]).resolve()
    with tempfile.TemporaryDirectory() as temp:
        root = Path(temp)
        launcher_bin = root / "launcher"
        real_bin = root / "real"
        launcher_bin.mkdir()
        real_bin.mkdir()
        (launcher_bin / "pi").symlink_to(launcher)
        fake = real_bin / "pi"
        fake.write_text("#!/usr/bin/env bash\nprintf 'REAL_PI argc=%d args=%s\\n' \"$#\" \"$*\"\n")
        fake.chmod(0o755)

        system_path = os.environ.get("PATH", "")
        output = run_in_tty(f"{launcher_bin}:{real_bin}:{system_path}")
        assert "REAL_PI argc=0 args=" in output, (
            "bare interactive pi did not start a new session directly"
        )


if __name__ == "__main__":
    main()
