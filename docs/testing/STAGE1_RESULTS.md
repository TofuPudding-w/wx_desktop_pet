# Stage 1 测试结果

构建 ID：`20261002T052143Z-27932d36`。本地源码基础版本 0.2.2，包含未发布的拥抱试作。所有三平台包来自同一份导出输入指纹，未打标签、提交、推送或更改已有 Release。

| 平台 | 当前结果 |
|---|---|
| Ubuntu 24.04 / GNOME Wayland + XWayland | 原生窗口检查与短测通过；并非所有 Linux 桌面均已支持 |
| Windows 11 / Intel x64 / 100% | 用户反馈该构建核心检查及 15 分钟运行 PASS；额外系统缩放／休眠恢复尚未测试 |
| macOS Universal 2 | x64 + arm64 架构、ZIP、.app 结构及执行权限检查通过；仅 ad-hoc 签名，未 notarize；无实机验证 |

## Ubuntu 实测

- 透明背景、点击穿透、双方拖拽、焦点保持、菜单和整体退出通过。
- 实际应用运行 120.001 秒，墙钟 130.22 秒；完成 4 次互动，退出码 0，无日志错误。峰值 RSS 303.20 MiB。
- 该短测不是两小时稳定性验收。
- 原生首轮测试受到另一运行实例干扰；已加入旧实例预检查，隔离复测通过。失败的首次结果不计入通过记录。
- 最终二进制 SHA-256：`a985e32c9d499c1f0d31ec96d7fcf0f55c1d967d9e35809a6efcd39971d90866`。

## 自动检查与打包

- 行为 29 项、入口 22 项、拥抱 274 项通过；行为检查含模拟 7200 秒。
- Python 29 项通过，含 Windows PE 架构／PCK、Linux 权限、macOS 双架构／权限拒绝用例。
- 三个平台 ZIP 校验及 SHA-256 一致；BUILD_INFO.json 具有相同构建 ID 与源码指纹。
- macOS 构建修正：启用 Universal 2 所需 ASTC 导入；Godot 标准模板路径映射到项目 .tools/godot-data，不污染用户全局模板目录。

## 下一步

将 Windows ZIP 复制到 Windows 11，完整解压后运行 CPPet.exe；分别用 test-eye-contact.cmd / test-hug.cmd 验证互动。填写 [Windows 反馈](WINDOWS11_FEEDBACK.md)，详细步骤见 [检查清单](STAGE1_CHECKLIST.md)。关闭旧桌宠后再启动测试版。

Windows 反馈通过之前，不宣称 Stage 1 跨平台验收完成。macOS 始终保持实验／未验证标注，等待志愿者实测。

原始检查记录见 stage1-evidence/；导出日志、包与校验文件在 dist/stage1/20261002T052143Z-27932d36/。

## 2026-10-02：大小设置与边界修复

后续测试构建：`20261002T091131Z-13c5fb54`，仍为 0.2.2 开发版，未发布新 Release。

- 新增右键「设置 · 角色大小」，100%／125%／150%／175%／200%，本机保存；小屏幕限制实际大小。两人、拥抱、输入区域及互动距离同步缩放，动画 FPS 保持不变。
- 待机结束前先判断可行方向；边界处仅向内走，没有足够空间则继续待机，消除向外启动又立即停止的闪烁。
- 自动检查通过：行为 29、入口／大小／边界 849、拥抱 289、美术 1524、对视 24、拖拽预览 35；Python 29 项通过。模拟 7200 秒不是实际两小时测试。
- 新 Linux 导出包原生测试通过：菜单切换 150% → 200% → 100%，透明背景、穿透、双方拖拽、焦点保持、窗口实际尺寸及整体退出。新增证据见 `stage1-evidence/size-native.txt`。
- 已填写的 Windows 反馈属于前一个构建，原文件保持不变；新构建需在 Windows 补测设置保存、大小、边界及互动。macOS 仍为实验、未实机验证。
- Windows 系统缩放测试和桌宠自身大小是两个独立设置，步骤见 STAGE1_CHECKLIST.md。

## Stage 1 closure

2026-10-02: User reports all Windows tests for the follow-up build passed. Stage 1 is accepted for the tested Ubuntu environment and Windows 11 Intel x64. macOS remains experimental/unverified; the user's Windows report does not certify macOS or every Windows configuration. Next: Stage 2 everyday controls.
