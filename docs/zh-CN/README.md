# 🚀 TermMirror (`term-mirror`)

[English](../../README.md) | [简体中文](README.md)

> **终端与网页实时同屏共状态，macOS 触控板丝滑长滚，退出即脱离保活不中断。**  
> **Real-time terminal and web mirroring with shared state, native macOS trackpad scrolling, and exit-to-detach persistence.**

[![Release](https://img.shields.io/badge/Release-v1.0.0-brightgreen.svg)](../../CHANGELOG.md)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](../../LICENSE)
[![Docker](https://img.shields.io/badge/Docker-Ready-2496ED?logo=docker&logoColor=white)](../../Dockerfile)
[![Platform](https://img.shields.io/badge/Platform-Linux%20%7C%20macOS%20%7C%20Windows-lightgrey)]()

---

### 🔍 核心热搜词 / 专为解决以下痛点而生

如果你在寻找以下任何需求，**TermMirror** 正是为你量身打造的：
- `docker mirror terminal to web`（Docker 终端实时同屏至 Web 网页）
- `docker persistent terminal session`（Docker 持久化终端会话，断线保活）
- `docker keep terminal running after exit`（Docker 退出终端时后台任务不停止）
- `docker terminal native scrolling mac trackpad`（解决 Mac 触控板在 Docker 中滚屏失效）
- `share terminal session web browser and ssh`（SSH 终端与浏览器共享同一终端会话）
- `run claude code in docker with web view`（在 Docker 中运行 Claude Code 并通过 Web 实时围观）
- `web terminal without tmux mouse hijacking`（不用 tmux、不劫持鼠标的丝滑 Web 终端）
- `docker pty stream to web and ssh`（原生 PTY 字节流双端直通分发）

---

## 💡 为什么必须专为 CLI 智能体设计？（核心设计哲学）

市面上绝大多数沙箱（如 E2B、各类云端执行器或普通无头 Docker）都是面向**“API 单次函数调用 / 无头执行（Headless Code Execution）”**设计的——输入是一个 JSON，输出是一段日志，根本不需要持续的人机交互。

但新一代顶尖 AI 编程智能体（Claude Code, Aider, OpenCodeInterpreter, Google Antigravity）**本质上是纯正的交互式命令行（Interactive CLI）**：
- **它们时刻需要输入（Continuous Human Input）**：执行命令的 `[y/N]` 审批确认、方向键切换模型与选项、Tab 补全、随时打断与补充 Prompt，以及人类随时敲键盘接管；
- **普通容器一跑就崩溃**：由于没有完整的交互式 PTY 管道，交互式 CLI 一启动就会报 `stdin is not a tty` 异常退出；
- **传统 tmux + ttyd 方案输入体验灾难**：虽然能跑，但键盘输入被层层拦截，鼠标滚轮无法原生滚屏，划选复制丢失字符，多端同屏时出现输入竞争与排版撕裂。

**TermMirror 的全部工程架构，就是为了解决“CLI 智能体需要极致原生输入、实时双端同屏、退出持久保活”这一核心痛点而生。**

---

## ✨ 核心特性

### 1. ⚡ 单主 PTY 字节流网关 (`pty-hub` & `pty-attach`)
- **彻底废除 `tmux` 与 `ttyd`**：采用自主研发的嵌入式 `pty-hub` 网关直接托管 Linux 内核 Master PTY；
- **Zero-Rewrite Passthrough**：原始字节流直通，无 Alternate Screen 劫持，无滚动边距限制。

### 2. 🖱️ “Terminal 为主、WebUI 为辅”的原生触控板长滚与 100% 划选复制
- **原生长滚动**：输出满屏后自然流式进入 macOS 自带 `Terminal.app` 原生 Scrollback，Mac 触控板两指自然滑动即可丝滑翻阅上万行历史；
- **ANSI 守卫 (ANSI Guard)**：服务端剥离鼠标上报控制序列，本地享受 100% 原生划词与 `Cmd+C` / `Cmd+V`；
- **右键防闪退**：Web Console 在 Capture 阶段拦截右键事件，鼠标划选多行点击右键选区不消失，浏览器原生“复制”菜单 100% 正常呼出。

### 3. 📐 逻辑栅格强锁 + CSS 等比缩放 (彻底消灭 `│···` 虚线)
- SSH 客户端作为唯一尺寸权威源（`SIGWINCH`）；
- Web Console 强锁服务端广播的行列数，并通过 CSS `transform: scale()` 像素级自适应视口，彻底消灭虚线边框与重绘错位。

### 4. 🌐 SSH (2222) 与 WebUI (7681) 1:1 双端同屏
- 浏览器点开即用，适合移动端、教学演示或快速分享；
- 本地终端随时接管，适合极客主力工作流，两端实时双向同步；
- 内存内置 **2MB 环形历史缓冲区**，断线重连毫秒级自动回放。

### 5. 🔄 退出保持，永不杀进程 (Session Continuity)
- 在 SSH 终端中输入 `exit` 或直接关闭终端窗口，**仅脱离当前连接**；
- 底层正在运行的 Agent、长耗时编译任务**绝不中断、永久保活**；
- 随时重新通过 SSH 连入或刷新浏览器，毫秒级无缝接回现场。

### 6. 👤 1000:1000 宿主属主对齐 + 免密 sudo
- 默认 `sandbox` 用户（UID: 1000, GID: 1000），与 Linux/macOS 宿主机主流用户 1:1 对齐，挂载写回代码绝不产生权限冲突；
- 预置免密 `sudo`，Agent 具备最高权限可自主安装系统工具，兼顾安全隔离与开发便利。

### 7. 📦 开箱即用与自举脚手架 (`WORKGITURL` Dogfooding)
- 容器默认将开源项目自身克隆至 `/workspace/term-mirror`，开箱即拥有现成的自举工程，即刻可以指挥 Agent 分析架构或编写变种；
- **挂载优先保障**：若用户挂载了已有代码（`-v $(pwd):/workspace`），系统智能避让，绝对不覆盖用户文件。

---

## 🚀 极速上手

### 1. 拉取 Docker 镜像

```bash
docker pull ghcr.io/koelhush/term-mirror:latest
```

### 2. 运行容器（常用运行用例）

#### 用例 A：标准后台启动

```bash
docker run -d --name term_mirror \
  -p 7681:7681 -p 2222:22 \
  -v $(pwd)/workspace:/workspace \
  ghcr.io/koelhush/term-mirror:latest
```

#### 用例 B：挂载公钥实现免密 SSH 登录

直接挂载宿主机 SSH 公钥，免去每次输入密码：

```bash
docker run -d --name term_mirror \
  -p 7681:7681 -p 2222:22 \
  -v $(pwd)/workspace:/workspace \
  -v ~/.ssh/id_rsa.pub:/home/sandbox/.ssh/authorized_keys:ro \
  ghcr.io/koelhush/term-mirror:latest
```

#### 用例 C：启动时自动克隆业务代码库（`WORKGITURL`）

利用开箱即用的自动拉取契约，容器启动即自动检出项目至 `/workspace`：

```bash
docker run -d --name term_mirror \
  -p 7681:7681 -p 2222:22 \
  -v $(pwd)/workspace:/workspace \
  -e WORKGITURL="https://github.com/your-org/your-project.git" \
  ghcr.io/koelhush/term-mirror:latest
```

### 3. 连接与双端同屏交互

- **WebUI 访问**：浏览器打开 `http://127.0.0.1:7681`，进入同屏终端；
- **本地 SSH 连接**：
  ```bash
  ssh -p 2222 sandbox@127.0.0.1
  # 默认密码: sandbox (如挂载了公钥则免密直接登入)
  ```
- **随时安全脱离**：输入 `exit` 或直接关闭终端窗口即可脱离连接，后台会话与 Agent 任务**持续保活永不中断**，重连瞬间恢复现场！

---

### 备选方式：Docker Compose

克隆本项目并一键启动：

```bash
git clone git@github.com:koelhush/term-mirror.git
cd term-mirror
docker compose up -d
```

---

## 🤖 智能体与 CLI 工具链定制指南 (3 种方式)

TermMirror 采用**完全厂商中立（Vendor-Neutral）**设计，未强行打包任何闭源制品。你可以根据自身工作流自由选择以下三种方式之一来装载所需的 CLI 工具：

### 途径一：进入终端直接安装（即开即用）
容器内已预装 Node.js、Python3、Git 与免密 `sudo`，直接在终端执行常规包管理命令即可：
- **Claude Code**: `npm install -g @anthropic-ai/claude-code && claude`
- **Aider**: `pip install aider-chat && aider`
- **Google Antigravity**: `curl -fsSL https://antigravity.google/cli/install.sh | bash && agy`
- **GitHub CLI**: `sudo apt-get update && sudo apt-get install -y gh`

### 途径二：修改 Dockerfile 构建专属镜像（构建期固化）
如果希望常用工具在每次启动新容器时秒级就绪，可基于底座镜像派生或直接在 `Dockerfile` 尾部添加指令：
```dockerfile
FROM term-mirror:latest
USER root
RUN npm install -g @anthropic-ai/claude-code \
    && pip install --no-cache-dir aider-chat
USER sandbox
```
执行构建：`docker build -t my-term-mirror:latest .`

### 途径三：直接给一个 Prompt 让 Agent 自己来干（终极省心）
得益于预置的 **免密 sudo 支持** 与 **系统执行准则**，你完全可以把脏活累活丢给 AI！在终端或连入的 Agent 对话框中直接粘贴以下 Prompt：

> **💡 开箱即用 Prompt 模板**：
> ```text
> 作为 Linux 系统与 DevOps 专家，请在当前沙箱环境中为我安装并配置 [Claude Code / Aider / GitHub CLI]：
> 1. 环境检测：检查当前环境是否有适宜的运行时（Node.js / Python / Go 等）；
> 2. 安装与配置：以全局最优雅的方式安装该 CLI（如有需要可直接使用免密 sudo），确保路径写入环境变量；
> 3. 验证与自测：运行该工具的 --version 验证其正常输出，并提示我如何配置鉴权 Token。
> ```

👉 更多深度定制技巧与最佳实践，详见完整指南：[**CUSTOM_AGENT_SETUP.md**](CUSTOM_AGENT_SETUP.md)。

---

## 🛠️ 环境变量与参数配置

| 环境变量 | 默认值 | 说明 |
| :--- | :--- | :--- |
| `WORKGITURL` | `git@github.com:koelhush/term-mirror.git` | 启动或 SSH 登录时自动拉取的目标 Git 仓库（设为 `""` 可完全禁用） |
| `WORKDIR` | `/workspace` | 沙箱内工作目录路径 |
| `WEB_PORT` | `7681` | WebUI 终端监听端口 |
| `NO_ATTACH` | `0` | 设为 `1` 时 SSH 登录不自动接入 PTY 网关，直接进入独立 Bash |

---

## 🧩 可插拔变种体系 (Flavors)

本项目遵循 **Core Base + Modular Flavors** 架构设计：
- **标准底座**：保持纯净、极致轻量与安全隔离；
- **领域变种**：可在 [`flavors/`](../../flavors/) 目录下按需扩展，例如：
  - [`flavors/dood`](../../flavors/dood/)：支持直接调度宿主机 Docker 的特化变种（Docker-outside-of-Docker）。

---

## 🤝 贡献与规范

欢迎参与社区贡献！
- 查看 [贡献指南](../../CONTRIBUTING.md) 了解 PR 流程与变种开发规范；
- 查看 [版本变更日志](../../CHANGELOG.md) 了解最新功能；
- 查看 [安全政策](../../SECURITY.md) 获取漏洞报告通道；
- 查看 [行为准则](../../CODE_OF_CONDUCT.md)。

---

## 📄 开源许可证

本项目采用 [Apache-2.0 许可证](../../LICENSE)。
