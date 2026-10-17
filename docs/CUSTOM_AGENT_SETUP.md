# 🛠️ Custom CLI Agent Setup Guide

[English](CUSTOM_AGENT_SETUP.md) | [Chinese](zh-CN/CUSTOM_AGENT_SETUP.md)

TermMirror is designed to be **100% vendor-neutral**. The base image does not bundle any proprietary, closed-source, or vendor-locked AI CLI tools. You have complete freedom to equip the sandbox with your favorite AI coding agents using any of the three approaches below:

---

## Approach 1: Direct Runtime Installation in Terminal (Instant & Ready)

Connect to the Web Console (`http://127.0.0.1:7681`) or SSH terminal (`ssh -p 2222 sandbox@127.0.0.1`). The sandbox already comes equipped with Node.js, Python3, Git, build-essential, and passwordless `sudo`. You can install your CLI agents directly:

### 1. Claude Code (Anthropic Official CLI)
```bash
npm install -g @anthropic-ai/claude-code
# Start interaction and complete browser OAuth
claude
```

### 2. Aider (Terminal Pair Programming)
```bash
pip install aider-chat
# Export your API key and launch
export OPENAI_API_KEY="your-key"
aider
```

### 3. OpenCodeInterpreter
```bash
pip install open-code-interpreter
```

### 4. Google Antigravity CLI
```bash
curl -fsSL https://antigravity.google/cli/install.sh | bash
agy
```

### 5. GitHub CLI (`gh`)
```bash
sudo apt-get update && sudo apt-get install -y gh
gh auth login
```

---

## Approach 2: Build a Custom Image via Dockerfile (Build-Time Persistence)

For team standardization, CI/CD pipelines, or permanent environments, bake your required CLI tools directly into a custom Docker image. You can extend the base image using a `Dockerfile.custom`:

### Example: `Dockerfile.custom`

```dockerfile
# Inherit from official neutral base
FROM term-mirror:latest

USER root

# 1. Install system utilities and GitHub CLI
RUN apt-get update && apt-get install -y --no-install-recommends \
    gh \
    htop \
    tmux \
    && rm -rf /var/lib/apt/lists/*

# 2. Globally install Node / Python AI agent CLIs
RUN npm install -g @anthropic-ai/claude-code \
    && pip install --no-cache-dir aider-chat

# 3. Set your preferred defaults
ENV AGENT_DEFAULT_MODEL="claude-3-7-sonnet"

USER sandbox
```

### Build & Run

```bash
# 1. Build your customized image
docker build -t my-term-mirror:latest -f Dockerfile.custom .

# 2. Run with one command
docker run -d --name my_term_mirror \
  -p 7681:7681 -p 2222:22 \
  -v $(pwd)/workspace:/workspace \
  my-term-mirror:latest
```

---

## Approach 3: Prompt-Driven Agent Self-Configuration (Zero Effort)

**Since you are running an AI Coding Agent, the smartest way is to delegate the setup task directly to the AI!**

Thanks to TermMirror's **passwordless sudo**, **standard Linux paths**, and **embedded operational rules**, you can paste the following prompt directly into your agent's chat interface. The agent will autonomously inspect prerequisites, install packages, and verify execution:

### 🌟 Universal Turnkey Prompt Template

```text
Act as a Linux systems and DevOps engineer. Please install and configure [Target CLI Name, e.g., Claude Code / Aider / GitHub CLI] inside this sandbox environment.

Follow these steps autonomously:
1. Environment Inspection: Check whether necessary runtimes (Node.js, Python, Go, etc.) and package managers are present.
2. Installation & Setup: Install the CLI globally in the most standard manner (use passwordless sudo if necessary), ensuring executable binaries are in PATH (/etc/environment or ~/.bashrc).
3. Verification: Run `<cmd> --version` or `<cmd> --help` to confirm it launches properly.
4. Summary Report: Report the installed command name, version, and instructions on how I should provide API authentication tokens.
```

### 💡 Specific Tool Prompt Examples

#### Example A: Installing Claude Code
```text
Please install the latest Anthropic Claude Code CLI in this sandbox:
1. Check the Node.js / npm environment;
2. Run `npm install -g @anthropic-ai/claude-code`;
3. Verify `claude --version`;
4. Guide me on how to supply the API key or complete the initial browser authentication.
```

#### Example B: Installing Aider + Code Search Tools
```text
Please set up Aider pair programming assistant in this sandbox:
1. Install `aider-chat` via pip;
2. Verify `ripgrep` and `git` are available;
3. Run `aider --version` to verify;
4. Prompt me on how to export ANTHROPIC_API_KEY or OPENAI_API_KEY.
```

---

## 💡 Best Practices

1. **Credential Safety**:
   - Avoid hardcoding personal API keys inside Dockerfiles.
   - Inject them at runtime using `docker run -e ANTHROPIC_API_KEY="sk-..."` or volume mount `~/.config`.
2. **Community Flavors**:
   - If your custom image caters to a common domain (such as Multimedia Processing, Web3, or Embedded Toolchains), consider sharing it under [`flavors/<flavor-name>`](../flavors/) as a community contribution!
