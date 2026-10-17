# TermMirror 运行准则 (Operational Rules)

欢迎使用 TermMirror 交互式终端同屏镜像环境。

## 🎯 环境与角色定义
- **运行环境**: 专为交互式 CLI 智能体打造的跨平台容器化开发沙箱（支持 Linux / macOS / Windows）
- **核心定位**: 为需要持续人机交互、键盘按键与选项输入的 CLI Agent 提供原生 PTY 字节流直通保障
- **默认用户**: `sandbox` (UID: 1000, GID: 1000)，拥有全量免密 sudo 到 root 权限
- **工作区路径**: 当前工作目录（`/workspace`）已持久化挂载至宿主机，文件属主与宿主机 1000:1000 保持一致，绝不污染宿主机权限
- **权限级别**: 最高授权沙箱环境，系统操作可直接 `sudo <cmd>` 无需密码

## 🛠️ 操作守则
1. **就地开发与验证**: 所有代码编写、单测与验证均在当前工作区完成。
2. **纯洁性保证**: 临时调试脚本与日志请在任务完成后清理，保持代码库整洁。
3. **自主执行**: 工具权限默认全自动放行，无需等待交互式确认。

## 📐 WebUI 与本地 Terminal 双端闭环同屏规范
- **单主 PTY 字节流分流网关 (pty-hub & pty-attach)**：
  - 彻底废除 `tmux` 与 `ttyd`，采用自主研发嵌入式 `pty-hub` 字节流网关托管 Linux 内核 Master PTY；
  - SSH 交互式连入通过超薄客户端 `pty-attach` 直通原始字节流（Zero-Rewrite Passthrough），无 Alternate Screen，无 `DECSTBM` 滚动边距；
- **“Terminal 为主、WebUI 为辅”的原生触控板长滚动与 100% 原生划选复制**：
  - 输出满屏后自然流式进入 macOS 自带 `Terminal.app` 原生 Scrollback，Mac 触控板两指自然滑动即可丝滑翻阅上万行历史，**彻底摆脱对键盘 Page Up / Page Down 的依赖**；
  - 服务端 ANSI 守卫（ANSI Guard）剥离鼠标上报控制序列，Terminal.app 享受 100% 原生鼠标划词与 `Cmd+C` / `Cmd+V` 复制粘贴；
  - Web Console 在 Capture 阶段拦截右键点击，鼠标划选多行点击右键选区不消失，浏览器原生“复制”菜单 100% 正常呼出；
- **单主控逻辑栅格强锁 + CSS 等比缩放 (彻底消灭 `│···` 虚线)**：
  - SSH 客户端作为唯一尺寸权威源（`SIGWINCH`），Web Console 禁用 `FitAddon`，强锁服务端广播的行列数，并通过 CSS `transform: scale()` 适配视口，彻底消灭虚线边框；
- **2MB 环形历史流回放、安全退出与终端洁净复位**：
  - 内存维护 2MB 环形缓冲区，WebUI 打开或 SSH 断线重连秒级补齐历史；
  - SSH 执行 `exit` 仅脱离当前连接，底层会话与任务永久保活；
  - `pty-attach` 退出时强制发送复位控制序列，100% 杜绝本地终端按键乱码或卡死。
