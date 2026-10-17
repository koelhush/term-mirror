# 🚀 TermMirror (`term-mirror`)

[English](README.md) | [Chinese](docs/zh-CN/README.md)

> **Real-time terminal and web mirroring with shared state, native macOS trackpad scrolling, and exit-to-detach persistence.**  
> **终端与网页实时同屏共状态，macOS 触控板丝滑长滚，退出即脱离保活不中断。**

[![Release](https://img.shields.io/badge/Release-v1.0.0-brightgreen.svg)](CHANGELOG.md)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![Docker](https://img.shields.io/badge/Docker-Ready-2496ED?logo=docker&logoColor=white)](Dockerfile)
[![Platform](https://img.shields.io/badge/Platform-Linux%20%7C%20macOS%20%7C%20Windows-lightgrey)]()

---

### 🔍 Top Search Queries

If you searched for any of the following, **TermMirror** was built specifically for you:
- `docker mirror terminal to web`
- `docker persistent terminal session`
- `docker keep terminal running after exit`
- `docker terminal native scrolling mac trackpad`
- `share terminal session web browser and ssh`
- `run claude code in docker with web view`
- `web terminal without tmux mouse hijacking`
- `docker pty stream to web and ssh`

---

## 💡 Why Build Specifically for CLI Agents? (Core Philosophy)

Most sandboxes on the market today (such as E2B, cloud execution sandboxes, or headless Docker containers) were architected for **"Headless Code Execution / API Function Calling"** — input is a single JSON payload, output is static log text, and no real-time interactive terminal is ever expected.

However, modern leading AI coding agents (such as **Claude Code, Aider, OpenCodeInterpreter, Google Antigravity**) are fundamentally **interactive command-line interfaces (Interactive CLIs)**:
- **Continuous Human Input**: Agents constantly prompt for `[y/N]` command execution approvals, arrow-key model/mode selections, Tab completion, interactive interruptions (`Ctrl+C`), and manual prompt interventions.
- **Headless Containers Crash Immediately**: Lacking a genuine Master PTY pipeline, interactive CLIs crash on launch with `stdin is not a tty`.
- **Legacy tmux + ttyd Experience is Broken**: Input keystrokes are intercepted, trackpad inertia scrolling fails, multi-line selection vanishes upon right-click, and dotted padding borders (`│···`) ruin layout formatting.

**TermMirror is engineered from the ground up to guarantee native TTY input fidelity, 1:1 web mirroring, and effortless long-context inspection for CLI agents.**

---

## ✨ Key Features

### 1. ⚡ Single-Master PTY Stream Gateway (`pty-hub` & `pty-attach`)
- **No `tmux` & No `ttyd`**: Replaced fragile terminal multiplexers with our embedded asynchronous gateway (`pty_hub.py`) managing the Linux kernel Master PTY directly.
- **Zero-Rewrite Passthrough**: Raw byte stream direct transmission without Alternate Screen hijacking or scroll margin constraints.

### 2. 🖱️ Native macOS Trackpad Inertia Scrolling & 100% Selection Copy
- **Native Scrollback**: Output streams naturally into `Terminal.app` native scrollback history. Two fingers glide smoothly through 10,000+ lines without keyboard shortcuts.
- **ANSI Guard**: Server-side filtering strips mouse reporting escape sequences, ensuring 100% native word selection and `Cmd+C` / `Cmd+V`.
- **Right-Click Selection Preservation**: Web Console captures right-click events during the event capture phase, preventing selection dismissal and preserving native browser copy menus.

### 3. 📐 Master Grid Lock + CSS Equal-Ratio Scaling (Zero `│···` Dotted Lines)
- SSH client serves as the sole size authority (`SIGWINCH`).
- Web Console locks grid dimensions and dynamically fits any browser viewport using CSS `transform: scale()`, completely eradicating dotted padding borders.

### 4. 🌐 1:1 Dual-Interface Mirroring (SSH :2222 + WebUI :7681)
- Open in browser for instant inspection, demonstrations, or mobile access.
- Attach locally via SSH for primary keyboard workflows — both sides update simultaneously in real-time.
- Built-in **2MB in-memory ring buffer** replays complete session history upon reconnection in milliseconds.

### 5. 🔄 Exit to Detach, Never Kills (Session Continuity)
- Typing `exit` in SSH or disconnecting your terminal session only detaches the client connection.
- Background tasks, compilation jobs, and long-running AI agents **never terminate**.
- Reconnecting via SSH or refreshing the browser instantly resumes the exact live state.

### 6. 👤 1000:1000 Host Ownership Alignment + Passwordless sudo
- Default `sandbox` user (UID: 1000, GID: 1000) matches standard Linux/macOS host users, preventing permission conflicts on mounted workspace volumes.
- Full passwordless `sudo` enables autonomous system package installations.

### 7. 📦 Self-Bootstrapping / Dogfooding Ready (`WORKGITURL`)
- Automatically clones the project itself into `/workspace/term-mirror` when empty, empowering the agent to inspect, modify, and build upon itself out of the box.
- **Mount-First Protection**: If existing code is mounted (`-v $(pwd):/workspace`), the container automatically yields, never overwriting user files.

---

## 🚀 Quick Start

### Option 1: Docker One-Liner

```bash
docker run -d --name term_mirror \
  -p 7681:7681 -p 2222:22 \
  -v $(pwd)/workspace:/workspace \
  ghcr.io/koelhush/term-mirror:latest
```

After startup:
- **Web Console**: Open `http://127.0.0.1:7681` in your browser.
- **Local SSH**:
  ```bash
  ssh -p 2222 sandbox@127.0.0.1
  # Default password: sandbox (passwordless if mounting ~/.ssh/authorized_keys)
  ```

---

### Option 2: Docker Compose

```bash
git clone git@github.com:koelhush/term-mirror.git
cd term-mirror
docker compose up -d
```

---

## 🤖 Customizing Your CLI Agent Toolchain (3 Ways)

TermMirror is strictly **vendor-neutral**. Choose any of the following 3 ways to equip your sandbox:

### Approach 1: Direct Runtime Terminal Install (Instant)
With pre-installed Node.js, Python3, and Git, simply run your package manager inside the container:
- **Claude Code**: `npm install -g @anthropic-ai/claude-code && claude`
- **Aider**: `pip install aider-chat && aider`
- **Google Antigravity**: `curl -fsSL https://antigravity.google/cli/install.sh | bash && agy`
- **GitHub CLI**: `sudo apt-get update && sudo apt-get install -y gh`

### Approach 2: Build a Custom Image via Dockerfile (Build-Time Persistence)
```dockerfile
FROM term-mirror:latest
USER root
RUN npm install -g @anthropic-ai/claude-code \
    && pip install --no-cache-dir aider-chat
USER sandbox
```
Build: `docker build -t my-term-mirror:latest .`

### Approach 3: Delegate Setup Directly to AI Agent (Prompt-Driven)
Paste this prompt into your agent terminal:

> **💡 Turnkey Prompt Template**:
> ```text
> Act as a Linux systems and DevOps engineer. Please install and configure [Claude Code / Aider / GitHub CLI] inside this sandbox:
> 1. Check prerequisites (Node.js/Python/Go, package managers);
> 2. Install the CLI globally (use passwordless sudo if needed), adding binaries to PATH;
> 3. Verify `<cmd> --version` works and advise on how to supply API keys.
> ```

👉 Detailed guide & tips: [**docs/CUSTOM_AGENT_SETUP.md**](docs/CUSTOM_AGENT_SETUP.md).

---

## 🛠️ Environment Variables

| Variable | Default | Description |
| :--- | :--- | :--- |
| `WORKGITURL` | `git@github.com:koelhush/term-mirror.git` | Target repository to auto-clone/pull (set to `""` to keep workspace empty) |
| `WORKDIR` | `/workspace` | Workspace root path inside container |
| `WEB_PORT` | `7681` | WebUI console listening port |
| `NO_ATTACH` | `0` | Set to `1` to bypass PTY hub on SSH login and drop into independent Bash |

---

## 🧩 Modular Flavors

Follows **Core Base + Modular Flavors** architecture:
- **Base**: Lean, secure, and vendor-neutral core;
- **Flavors**: Extend under [`flavors/`](flavors/), e.g.:
  - [`flavors/dood`](flavors/dood/): Docker-outside-of-Docker flavor for agents needing Docker container orchestration.

---

## 🤝 Community & Governance

- Read [Contributing Guidelines](CONTRIBUTING.md) for PR & Flavor standards;
- Read [Changelog](CHANGELOG.md) for version release history;
- Read [Security Policy](SECURITY.md) for vulnerability reporting;
- Read [Code of Conduct](CODE_OF_CONDUCT.md).

---

## 📄 License

Distributed under the [Apache-2.0 License](LICENSE).
