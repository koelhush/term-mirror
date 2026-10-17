# 🛠️ 智能体与 CLI 工具链安装与定制指南 (Custom Agent Setup Guide)

TermMirror 底座保持绝对纯净与厂商中立，不强行捆绑任何专有或闭源智能体工具。开发者可以根据自身工作流偏好，自由选择以下三种方式之一来装载所需的 CLI 工具：

---

## 途径一：进入沙箱终端即时安装（即开即用）

进入 Web Console (`http://127.0.0.1:7681`) 或 SSH 终端 (`ssh -p 2222 sandbox@127.0.0.1`) 后，容器内已预装 Node.js、Python3、Git、Build-essential 与免密 `sudo`。你可以直接像操作本地 Linux 主机一样安装任何 CLI 工具：

### 1. Claude Code (Anthropic 官方 CLI)
```bash
npm install -g @anthropic-ai/claude-code
# 启动认证与交互
claude
```

### 2. Aider (终端配对编程神器)
```bash
pip install aider-chat
# 配置你的 API Key 并启动
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

## 途径二：修改 Dockerfile 构建专属镜像（环境固化）

如果希望常用工具在每次启动新容器时秒级就绪，推荐在构建期将其固化至镜像中。你可以直接修改根目录的 `Dockerfile`，或者新建 `Dockerfile.custom` 基于底座进行扩展：

### 示例：创建 `Dockerfile.custom`

```dockerfile
# 继承自官方纯净底座
FROM term-mirror:latest

USER root

# 1. 安装系统级常用依赖与 GitHub CLI
RUN apt-get update && apt-get install -y --no-install-recommends \
    gh \
    htop \
    tmux \
    && rm -rf /var/lib/apt/lists/*

# 2. 全局预装 Node / Python 类 AI Agent 工具
RUN npm install -g @anthropic-ai/claude-code \
    && pip install --no-cache-dir aider-chat

# 3. 预设你喜爱的环境变量
ENV AGENT_DEFAULT_MODEL="claude-3-7-sonnet"

USER sandbox
```

### 构建与启动

```bash
# 1. 构建你的专属镜像
docker build -t my-term-mirror:latest -f Dockerfile.custom .

# 2. 一键启动
docker run -d --name my_term_mirror \
  -p 7681:7681 -p 2222:22 \
  -v $(pwd)/workspace:/workspace \
  my-term-mirror:latest
```

---

## 途径三：直接给一个 Prompt 让 Agent 自己来干（AI 自动装配）

**既然你运行的是 AI Coding Agent，最极客、最省心的方式是直接把脏活累活丢给 AI！**

得益于 TermMirror 预置的 **全量免密 sudo 支持**、**标准 Linux 目录结构** 以及 **系统准则注入机制**，你只需要在沙箱终端或任何连入的 Agent 对话框中粘贴以下 Prompt，Agent 就会自主阅读文档、检测环境、执行安装并完成自测：

### 🌟 通用开箱即用 Prompt 模板

```text
作为 Linux 系统工程与 DevOps 专家，请在当前沙箱环境中为我安装并配置 [输入你想安装的工具名，如: Claude Code / Aider / GitHub CLI]。

请按以下步骤自主执行：
1. 环境检测：检查当前环境是否有适宜的运行时（Node.js / Python / Go 等）以及包管理器版本；
2. 安装与配置：以全局最优雅的方式安装该 CLI（如有需要可直接使用免密 sudo），并将其可执行路径确保写入 /etc/environment 或 ~/.bashrc；
3. 验证与测试：运行该工具的 --version 或帮助命令，验证其能够正常唤起并输出；
4. 结案汇报：向我汇报安装好的命令名、版本号以及后续首次使用所需配置的鉴权环境变量（如 API KEY）。
```

### 💡 针对特定工具的开箱 Prompt 示例

#### 示例 A：配置 Claude Code
```text
请帮我在当前沙箱中安装最新版 Anthropic Claude Code CLI：
1. 检查 Node.js / npm 环境；
2. 执行 npm install -g @anthropic-ai/claude-code 安装；
3. 验证 claude --version；
4. 告诉我如何输入 API Key 或完成初次网页 OAuth 授权。
```

#### 示例 B：配置 Aider + 深度代码检索
```text
请在当前环境中为我部署 Aider 配对编程助手：
1. 使用 pip 在全局或 sandbox 用户环境安装 aider-chat；
2. 确保已预装 ripgrep 与 git；
3. 运行 aider --version 验证安装；
4. 提示我如何通过环境变量导出 ANTHROPIC_API_KEY 或 OPENAI_API_KEY。
```

---

## 💡 最佳实践与建议

1. **凭证隔离与持久化**：
   - 避免将个人的 API Key 硬编码在 Dockerfile 中；
   - 推荐在 `docker run` 时通过 `-e ANTHROPIC_API_KEY="sk-..."` 注入，或者挂载本地配置文件（如 `~/.config`）；
2. **变种归档（Flavors）**：
   - 如果你的定制镜像具有通用的行业场景（如多媒体处理、Web3 开发、嵌入式交叉编译），欢迎将其整理为变种并提交至 `flavors/<flavor-name>` 贡献给开源社区！
