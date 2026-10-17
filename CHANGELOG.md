# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.0] - 2026-10-18

### 🚀 Initial Public Release

#### Features & Highlights
- **Purpose-Built for Interactive CLI Agents**: Specifically designed for modern AI Coding CLIs that require continuous, bi-directional terminal input (`y/N` confirmations, arrow-key menu selection, and human-in-the-loop takeover), eliminating headless TTY failures.
- **Single-Master PTY Byte-Stream Hub (`pty-hub`)**:
  - Replaced legacy `tmux` and `ttyd` with an ultra-lightweight, embedded asynchronous byte-stream gateway (`pty_hub.py`).
  - Zero-Rewrite passthrough preserving pure raw byte streams without Alternate Screen hijacking.
- **Native macOS Trackpad Long-Scrolling**:
  - Full stream enters `Terminal.app` native scrollback buffer naturally. Smooth two-finger inertia scrolling through 10,000+ lines without keyboard shortcuts.
- **100% Native Selection & Context Menu (ANSI Guard)**:
  - Strips mouse tracking sequences (`?1000h` / `?1002h` / `?1006h`) at server level to avoid hijacking local Terminal selection.
  - Intercepts Web Console right-click events during the capture phase, preserving multi-line text selections and allowing native browser context menus.
- **Single-Master Logical Grid Lock & CSS Equal-Ratio Scaling**:
  - SSH client acts as the authoritative window size source (`SIGWINCH`).
  - Web Console disables `FitAddon` and locks to broadcast dimensions, dynamically scaled via CSS `transform: scale()` to completely eradicate dotted padding borders (`│···`).
- **2MB Ring Buffer**:
  - High-performance in-memory ring buffer ensures millisecond replay upon WebUI reload or SSH reconnects.
- **1000:1000 User & NOPASSWD Sudo**:
  - Standard non-root `sandbox` user matching host UID/GID (1000:1000), preventing file permission corruption on mounted directories.
  - Sudo without password enabled for full automation autonomy.
- **Modular Flavors System**:
  - Core base remains lean and decoupled; custom domain workloads (such as `dood` for Docker orchestration) extend neatly under `flavors/`.
- **Self-Bootstrapping / Dogfooding Ready (`WORKGITURL`)**:
  - Automatically fetches project repo upon startup into `/workspace/term-mirror` when empty, providing an immediate environment for the Agent to inspect and build upon itself.
