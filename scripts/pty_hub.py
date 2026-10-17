#!/usr/bin/env python3
"""
pty_hub.py - Single-Master PTY Byte-Stream Hub Daemon
Manages Linux Kernel Master PTY, 2MB RingBuffer, ANSI guard,
and multiplexes stream between SSH (Unix Socket) and WebUI (WebSocket).
"""

import asyncio
import collections
import fcntl
import json
import logging
import os
import pty
import pwd
import re
import signal
import struct
import sys
import termios
from aiohttp import web

logging.basicConfig(level=logging.INFO, format="[pty-hub] %(asctime)s %(message)s")
logger = logging.getLogger("pty-hub")

SOCKET_PATH = "/tmp/pty_hub.sock"
WEB_PORT = int(os.environ.get("WEB_PORT", 7681))
WEB_DIR = os.environ.get("WEB_DIR", "/opt/agentbox/web")
WORKDIR = os.environ.get("WORKDIR", "/workspace")
RING_BUFFER_MAX_BYTES = 2 * 1024 * 1024  # 2MB

# Strip mouse reporting escape sequences that cause Terminal.app to hijack trackpad/mouse
# (\e[?1000h, \e[?1002h, \e[?1003h, \e[?1006h)
MOUSE_ENABLE_RE = re.compile(rb"\x1b\[\?(?:1000|1002|1003|1006)(?:;\d+)*h")

# Terminal capability queries that should NEVER reach external terminals or RingBuffer
TERM_QUERY_RE = re.compile(
    rb"\x1b\[\??[0-9;]*c"
    rb"|\x1b\[>[0-9;]*c"
    rb"|\x1b\](?:10|11|12);\?(?:\x07|\x1b\\)?"
    rb"|\x1b\[\?[0-9;]+(?:\$[py])"
    rb"|\x1b\[\??6n"
)

# Unsolicited terminal report replies on stdin that should never be forwarded to bash
TERM_REPLY_RE = re.compile(
    rb"\x1b\[\??[0-9;]*c"
    rb"|\x1b\[>[0-9;]*c"
    rb"|\x1b\[\?[0-9;]+\$[py]"
    rb"|\x1b\](?:10|11|12);[^\x07\x1b]*(?:\x07|\x1b\\)?"
    rb"|\x1b\[[0-9;]+R"
    rb"|\x1b\[[IO]"
)


class RingBuffer:
    def __init__(self, max_bytes: int):
        self.chunks = collections.deque()
        self.total_bytes = 0
        self.max_bytes = max_bytes

    def append(self, data: bytes):
        if not data:
            return
        self.chunks.append(data)
        self.total_bytes += len(data)
        while self.total_bytes > self.max_bytes and self.chunks:
            removed = self.chunks.popleft()
            self.total_bytes -= len(removed)

    def dump(self) -> bytes:
        return b"".join(self.chunks)


class PtyHub:
    def __init__(self):
        self.master_fd = None
        self.shell_pid = None
        self.rows = 40
        self.cols = 140
        self.ring_buffer = RingBuffer(RING_BUFFER_MAX_BYTES)
        self.ssh_clients = set()  # set of asyncio.StreamWriter
        self.web_clients = set()  # set of web.WebSocketResponse
        self.loop = None
        self.running = True

    def spawn_shell(self):
        pid, master_fd = pty.fork()
        if pid == 0:
            # Child process: configure sandbox user environment and launch bash
            try:
                pw = pwd.getpwnam("sandbox")
                os.initgroups("sandbox", pw.pw_gid)
                os.setgid(pw.pw_gid)
                os.setuid(pw.pw_uid)
            except Exception:
                pass

            target_dir = WORKDIR
            work_git = os.environ.get("WORKGITURL")
            if work_git:
                clean_url = work_git.rstrip("/")
                repo_name = os.path.splitext(os.path.basename(clean_url))[0]
                cand = os.path.join(WORKDIR, repo_name)
                if os.path.isdir(cand):
                    target_dir = cand

            try:
                os.chdir(target_dir)
            except Exception:
                try:
                    os.chdir(WORKDIR)
                except Exception:
                    try:
                        os.chdir("/home/sandbox")
                    except Exception:
                        pass

            env = os.environ.copy()
            env["HOME"] = "/home/sandbox"
            env["USER"] = "sandbox"
            env["LOGNAME"] = "sandbox"
            env["SHELL"] = "/bin/bash"
            env["TERM"] = "xterm-256color"
            env["AGENT_SANDBOX"] = "1"
            env["TERM_MIRROR"] = "1"
            os.environ.clear()
            os.environ.update(env)

            os.execvp("/bin/bash", ["/bin/bash", "-l"])
        else:
            self.shell_pid = pid
            self.master_fd = master_fd

            # Set non-blocking on master_fd
            flags = fcntl.fcntl(master_fd, fcntl.F_GETFL)
            fcntl.fcntl(master_fd, fcntl.F_SETFL, flags | os.O_NONBLOCK)

            self.set_pty_size(self.rows, self.cols)
            logger.info(f"Spawned shell PID {pid} on master PTY fd {master_fd} (initial {self.cols}x{self.rows})")
            if self.loop is not None:
                self.loop.add_reader(self.master_fd, self.on_pty_output)

    def set_pty_size(self, rows: int, cols: int):
        self.rows = max(10, rows)
        self.cols = max(20, cols)
        if self.master_fd is not None:
            try:
                winsize = struct.pack("HHHH", self.rows, self.cols, 0, 0)
                fcntl.ioctl(self.master_fd, termios.TIOCSWINSZ, winsize)
            except OSError as e:
                logger.warning(f"Failed to set TIOCSWINSZ: {e}")

    def on_pty_output(self):
        try:
            raw_data = os.read(self.master_fd, 65536)
        except (OSError, BlockingIOError):
            raw_data = b""

        if not raw_data:
            # Shell exited or PTY broken
            logger.warning("PTY output EOF/closed, restarting shell...")
            try:
                self.loop.remove_reader(self.master_fd)
                os.close(self.master_fd)
            except Exception:
                pass

            # Reap zombie child process
            if self.shell_pid is not None:
                try:
                    os.waitpid(self.shell_pid, os.WNOHANG)
                except Exception:
                    pass

            # Clear ring buffer so dead shell's logout is not replayed
            self.ring_buffer = RingBuffer(RING_BUFFER_MAX_BYTES)

            if self.running:
                self.loop.call_later(0.5, self.spawn_shell)
            return

        # Strip mouse reporting sequences to protect macOS Terminal.app native scroll & select
        clean_data = MOUSE_ENABLE_RE.sub(b"", raw_data)

        # Strip terminal capability queries so clients NEVER receive them
        clean_data = TERM_QUERY_RE.sub(b"", clean_data)
        self.ring_buffer.append(clean_data)

        # 1. Stream 100% raw bytes to all connected SSH clients
        for writer in list(self.ssh_clients):
            try:
                writer.write(clean_data)
            except Exception:
                self.ssh_clients.discard(writer)

        # 2. Stream raw bytes to all connected WebUI WebSockets
        for ws in list(self.web_clients):
            if not ws.closed:
                asyncio.create_task(self.send_ws_bytes(ws, clean_data))
            else:
                self.web_clients.discard(ws)

    async def send_ws_bytes(self, ws: web.WebSocketResponse, data: bytes):
        try:
            await ws.send_bytes(data)
        except Exception:
            self.web_clients.discard(ws)

    async def broadcast_resize_to_web(self):
        msg = json.dumps({"type": "resize", "cols": self.cols, "rows": self.rows})
        for ws in list(self.web_clients):
            if not ws.closed:
                try:
                    await ws.send_str(msg)
                except Exception:
                    self.web_clients.discard(ws)
            else:
                self.web_clients.discard(ws)

    # ─── SSH Client Handler (Unix Domain Socket) ───
    async def handle_ssh_client(self, reader: asyncio.StreamReader, writer: asyncio.StreamWriter):
        logger.info("SSH client attached via Unix socket")
        history = self.ring_buffer.dump()
        if history:
            try:
                writer.write(history)
                await writer.drain()
            except Exception:
                writer.close()
                return

        self.ssh_clients.add(writer)
        try:
            while self.running:
                header = await reader.readexactly(1)
                pkt_type = header[0]
                if pkt_type == 0:
                    # Stdin data
                    len_bytes = await reader.readexactly(2)
                    (length,) = struct.unpack("!H", len_bytes)
                    payload = await reader.readexactly(length)
                    clean_payload = TERM_REPLY_RE.sub(b"", payload)
                    if clean_payload and self.master_fd is not None:
                        os.write(self.master_fd, clean_payload)

                elif pkt_type == 1:
                    # Resize packet (rows, cols)
                    size_bytes = await reader.readexactly(4)
                    rows, cols = struct.unpack("!HH", size_bytes)
                    if rows > 0 and cols > 0:
                        logger.info(f"SSH client requested resize: {cols}x{rows}")
                        self.set_pty_size(rows, cols)
                        await self.broadcast_resize_to_web()
        except (asyncio.IncompleteReadError, ConnectionResetError, BrokenPipeError):
            pass
        except Exception as e:
            logger.warning(f"SSH client error: {e}")
        finally:
            self.ssh_clients.discard(writer)
            try:
                writer.close()
                await writer.wait_closed()
            except Exception:
                pass
            logger.info("SSH client detached")

    # ─── WebUI Client Handler (WebSocket) ───
    async def handle_ws(self, request: web.Request):
        ws = web.WebSocketResponse()
        await ws.prepare(request)
        logger.info("WebUI client connected via WebSocket")
        self.web_clients.add(ws)

        # 1. Send current locked grid dimensions
        await ws.send_str(json.dumps({"type": "resize", "cols": self.cols, "rows": self.rows}))

        # 2. Replay history
        history = self.ring_buffer.dump()
        if history:
            await ws.send_bytes(history)

        try:
            async for msg in ws:
                if msg.type == web.WSMsgType.BINARY:
                    clean_data = TERM_REPLY_RE.sub(b"", msg.data)
                    if clean_data and self.master_fd is not None:
                        os.write(self.master_fd, clean_data)
                elif msg.type == web.WSMsgType.TEXT:
                    try:
                        data = json.loads(msg.data)
                        if data.get("type") == "input":
                            raw_input = data.get("data", "").encode("utf-8")
                            clean_input = TERM_REPLY_RE.sub(b"", raw_input)
                            if clean_input and self.master_fd is not None:
                                os.write(self.master_fd, clean_input)
                    except Exception:
                        pass
                elif msg.type in (web.WSMsgType.CLOSE, web.WSMsgType.ERROR):
                    break
        finally:
            self.web_clients.discard(ws)
            logger.info("WebUI client disconnected")
        return ws

    async def handle_index(self, request: web.Request):
        index_path = os.path.join(WEB_DIR, "index.html")
        if os.path.exists(index_path):
            return web.FileResponse(index_path)
        return web.Response(text="<h1>Agent Sandbox Web Console</h1><p>index.html not found</p>", content_type="text/html")


async def main():
    hub = PtyHub()
    hub.loop = asyncio.get_running_loop()

    # Clean up stale unix socket
    if os.path.exists(SOCKET_PATH):
        try:
            os.unlink(SOCKET_PATH)
        except OSError:
            pass

    # Start Unix Domain Socket server for SSH attach clients
    server = await asyncio.start_unix_server(hub.handle_ssh_client, SOCKET_PATH)
    try:
        os.chmod(SOCKET_PATH, 0o666)
    except Exception as e:
        logger.warning(f"Failed to chmod socket: {e}")

    # Launch initial shell
    hub.spawn_shell()

    # Setup web application
    app = web.Application()
    app.router.add_get("/", hub.handle_index)
    app.router.add_get("/ws", hub.handle_ws)

    static_dir = os.path.join(WEB_DIR, "static")
    if os.path.isdir(static_dir):
        app.router.add_static("/static/", path=static_dir, name="static")

    runner = web.AppRunner(app)
    await runner.setup()
    site = web.TCPSite(runner, "0.0.0.0", WEB_PORT)
    await site.start()
    logger.info(f"Web console running on http://0.0.0.0:{WEB_PORT}")
    logger.info(f"PTY Unix socket listening on {SOCKET_PATH}")

    # Shutdown signal handlers
    stop_event = asyncio.Event()

    def on_stop(signum, frame):
        hub.running = False
        stop_event.set()

    for sig in (signal.SIGINT, signal.SIGTERM):
        signal.signal(sig, on_stop)

    await stop_event.wait()
    logger.info("Shutting down pty-hub...")

    server.close()
    await server.wait_closed()
    await runner.cleanup()

    if os.path.exists(SOCKET_PATH):
        try:
            os.unlink(SOCKET_PATH)
        except Exception:
            pass

    if hub.master_fd is not None:
        try:
            os.close(hub.master_fd)
        except Exception:
            pass
    if hub.shell_pid is not None:
        try:
            os.kill(hub.shell_pid, signal.SIGTERM)
        except Exception:
            pass


if __name__ == "__main__":
    asyncio.run(main())
