# TermMirror Operational Rules

Welcome to TermMirror interactive terminal mirroring environment.

## 🎯 Environment & Role Definitions
- **Runtime Environment**: Cross-platform containerized sandbox purpose-built for interactive CLI agents (supports Linux / macOS / Windows).
- **Core Mission**: Provides zero-delay raw PTY byte-stream passthrough for CLI Agents requiring continuous human input, keystrokes, and option approvals.
- **Default User**: `sandbox` (UID: 1000, GID: 1000), granted full passwordless sudo permissions to root.
- **Workspace Path**: Working directory (`/workspace`) persisted from host; ownership aligned with host 1000:1000 to eliminate permission corruption.
- **Privilege Level**: Highest autonomous sandbox tier; system commands can execute `sudo <cmd>` without prompting.

## 🛠️ Operational Principles
1. **In-Place Development & Verification**: All code editing, unit tests, and validation must be performed within the active workspace.
2. **Repository Cleanliness**: Temporary debugging scripts and intermediate logs must be cleaned up after task completion.
3. **Autonomous Execution**: Tool and command execution permissions are auto-approved by default; do not stall on interactive permission confirmations.

## 📐 Dual-Interface PTY Mirroring Guidelines
- **Single-Master PTY Stream Gateway (`pty-hub` & `pty-attach`)**:
  - Replaced `tmux` and `ttyd` with embedded `pty-hub` managing the Linux kernel Master PTY.
  - SSH attach client (`pty-attach`) provides raw Zero-Rewrite Passthrough without Alternate Screen or scroll margin restrictions.
- **Native macOS Trackpad Long-Scrolling & 100% Native Selection**:
  - Terminal output flows naturally into macOS `Terminal.app` native scrollback buffer; use two fingers on trackpad to smoothly review tens of thousands of history lines.
  - Server-side ANSI Guard strips mouse-reporting sequences, preserving native word selection and `Cmd+C` / `Cmd+V`.
  - Web Console intercepts right-clicks during capture phase to prevent selection dismissal and allow native browser context menus.
- **Master Grid Lock + CSS Equal-Ratio Scaling**:
  - SSH client serves as the sole size authority (`SIGWINCH`); Web Console locks grid dimensions and scales via CSS `transform: scale()`, eliminating dotted padding borders (`│···`).
- **2MB Ring Buffer Replay & Clean Reset**:
  - In-memory 2MB ring buffer replays full session history immediately upon reconnection.
  - Exiting SSH only detaches the client connection; background sessions and tasks remain persistent.
  - `pty-attach` sends a full terminal reset sequence on exit to prevent local terminal corruption.
