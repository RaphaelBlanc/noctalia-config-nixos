"""Saisie ZLE préservée et accueil regroupé pendant une rafale de SIGWINCH."""
import fcntl
import os
from pathlib import Path
import pty
import select
import signal
import struct
import sys
import tempfile
import termios
import time


with tempfile.TemporaryDirectory() as directory:
    home = Path(directory)
    binary = home / ".local/bin"
    binary.mkdir(parents=True)
    greeting = binary / "nc-greeting"
    greeting.write_text('#!/bin/sh\necho GREETING\necho call >> "$HOME/calls"\n')
    greeting.chmod(0o755)
    pid, fd = pty.fork()
    if pid == 0:
        os.environ.update(HOME=directory, TERM="xterm-256color",
                          PATH=str(binary) + ":" + os.environ["PATH"], PS1="PROMPT> ")
        os.environ.pop("FASTFETCH_SHOWN", None)
        os.execvp("zsh", ["zsh", "-df"])
    output = bytearray()

    def wait_for(predicate, timeout=5):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if predicate():
                return
            ready, _, _ = select.select([fd], [], [], 0.05)
            if ready:
                output.extend(os.read(fd, 65536))
        raise AssertionError(bytes(output).decode(errors="replace"))

    try:
        wait_for(lambda: b"PROMPT> " in output)
        os.write(fd, ("source " + str(Path(sys.argv[1]).resolve()) + "\n").encode())
        wait_for(lambda: (home / "calls").exists())
        os.write(fd, b"print -r -- 'PRESERVED TEXT' > ~/result")
        for width in range(80, 92):
            fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", 30, width, 0, 0))
            os.kill(pid, signal.SIGWINCH)
            time.sleep(0.01)
        wait_for(lambda: len((home / "calls").read_text().splitlines()) >= 2)
        os.write(fd, b"\n")
        wait_for(lambda: (home / "result").exists())
        assert (home / "result").read_text() == "PRESERVED TEXT\n"
        assert len((home / "calls").read_text().splitlines()) <= 3
        assert b"widgets can only be called" not in output
        print("Zsh : saisie conservée et SIGWINCH regroupés.")
    finally:
        os.kill(pid, signal.SIGKILL)
        os.close(fd)
        os.waitpid(pid, 0)
