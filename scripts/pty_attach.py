#!/usr/bin/env python3
"""
pty_attach.py - Thin Raw-Stream Attach Client for SSH sessions.
Directly bridges local Terminal.app to pty-hub with 100% raw byte passthrough,
relays SIGWINCH window size, and resets terminal cleanly on detachment.
"""

import fcntl
import os
import re
import select
import signal
import socket
import struct
import sys
import termios
import time
import tty

SOCKET_PATH = "/tmp/pty_hub.sock"

# Comprehensive terminal reset sequence:
# Disable mouse reporting (?1000l/?1002l/?1003l/?1006l), disable bracketed paste (?2004l),
# reset scroll margins (\e[r), show cursor (?25h), reset color and attributes (\e[0m)
TERMINAL_RESET_SEQ = b"\x1b[?1000l\x1b[?1002l\x1b[?1003l\x1b[?1006l\x1b[?2004l\x1b[r\x1b[?25h\x1b[0m\r\n"

# Unsolicited terminal report replies on stdin that should never be forwarded to bash
TERM_REPLY_RE = re.compile(
    rb"\x1b\[\??[0-9;]*c"
    rb"|\x1b\[>[0-9;]*c"
    rb"|\x1b\[\?[0-9;]+\$[py]"
    rb"|\x1b\](?:10|11|12);[^\x07\x1b]*(?:\x07|\x1b\\)?"
    rb"|\x1b\[[0-9;]+R"
    rb"|\x1b\[[IO]"
)

# Incomplete escape sequence at the end of a read buffer
INCOMPLETE_ESC_RE = re.compile(rb"\x1b(?:\[\??[0-9;]*|\>[0-9;]*|\][^\x07\x1b]*)?$")


def get_terminal_size(fd: int):
    try:
        winsize = fcntl.ioctl(fd, termios.TIOCGWINSZ, b"\x00" * 8)
        rows, cols, _, _ = struct.unpack("HHHH", winsize)
        return rows, cols
    except Exception:
        return 40, 140


def send_winsize(sock: socket.socket, fd: int):
    rows, cols = get_terminal_size(fd)
    if rows > 0 and cols > 0:
        pkt = struct.pack("!BHH", 1, rows, cols)
        sock.sendall(pkt)


def connect_hub_socket(timeout_sec=8.0):
    start = time.time()
    while time.time() - start < timeout_sec:
        if os.path.exists(SOCKET_PATH):
            try:
                s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
                s.connect(SOCKET_PATH)
                return s
            except (ConnectionRefusedError, FileNotFoundError):
                s.close()
        time.sleep(0.3)
    return None


def main():
    stdin_fd = sys.stdin.fileno()
    stdout_fd = sys.stdout.fileno()

    if not os.isatty(stdin_fd):
        sys.stderr.write("pty_attach: stdin is not a tty\n")
        sys.exit(1)

    sock = connect_hub_socket()
    if not sock:
        sys.stderr.write("pty_attach: pty-hub daemon is not running\n")
        sys.exit(1)

    old_tty_attrs = termios.tcgetattr(stdin_fd)

    # Use a self-pipe for signal handling
    r_sig, w_sig = os.pipe()
    flags = fcntl.fcntl(w_sig, fcntl.F_GETFL)
    fcntl.fcntl(w_sig, fcntl.F_SETFL, flags | os.O_NONBLOCK)

    def on_sigwinch(signum, frame):
        try:
            os.write(w_sig, b"w")
        except OSError:
            pass

    def on_sigterm(signum, frame):
        try:
            os.write(w_sig, b"q")
        except OSError:
            pass

    signal.signal(signal.SIGWINCH, on_sigwinch)
    signal.signal(signal.SIGTERM, on_sigterm)
    signal.signal(signal.SIGINT, on_sigterm)
    signal.signal(signal.SIGHUP, on_sigterm)

    try:
        # Put terminal in raw mode
        tty.setraw(stdin_fd)
        # Send initial window size immediately
        send_winsize(sock, stdin_fd)

        incomplete_buf = b""
        while True:
            try:
                rlist, _, _ = select.select([stdin_fd, sock, r_sig], [], [], 1.0)
            except InterruptedError:
                continue

            if r_sig in rlist:
                try:
                    sig_bytes = os.read(r_sig, 64)
                    if b"q" in sig_bytes:
                        break
                    if b"w" in sig_bytes:
                        send_winsize(sock, stdin_fd)
                except OSError:
                    pass

            if stdin_fd in rlist:
                try:
                    chunk = os.read(stdin_fd, 4096)
                except OSError:
                    chunk = b""

                if not chunk:
                    break

                data = incomplete_buf + chunk
                incomplete_buf = b""

                # Ctrl+] (ASCII 0x1d) escape to detach
                if b"\x1d" in data:
                    break

                # If data ends with an incomplete escape sequence, buffer it
                m = INCOMPLETE_ESC_RE.search(data)
                if m and len(m.group(0)) < 64:
                    incomplete_buf = m.group(0)
                    data = data[:m.start()]

                if not data:
                    continue

                # Filter unsolicited terminal capability report replies
                data = TERM_REPLY_RE.sub(b"", data)
                if not data:
                    continue

                # Frame: 0x00 + 2-byte length + payload
                header = struct.pack("!BH", 0, len(data))
                sock.sendall(header + data)

            if sock in rlist:
                try:
                    data = sock.recv(65536)
                except OSError:
                    data = b""

                if not data:
                    break

                os.write(stdout_fd, data)

    finally:
        # 1. Restore local TTY attributes
        try:
            termios.tcsetattr(stdin_fd, termios.TCSADRAIN, old_tty_attrs)
        except Exception:
            pass

        # 2. Issue terminal clean-up reset sequence
        try:
            os.write(stdout_fd, TERMINAL_RESET_SEQ)
        except Exception:
            pass

        try:
            sock.close()
        except Exception:
            pass
        try:
            os.close(r_sig)
            os.close(w_sig)
        except Exception:
            pass


if __name__ == "__main__":
    main()
