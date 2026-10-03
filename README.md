# 忘羡桌宠 · v0.3.0 预览版

> v0.3.0 是当前首个分享版候选；发布说明与平台限制见 [v0.3.0](releases/v0.3.0.md)。通过标签工作流创建预发布草稿，尚未公开。后文 v0.2.2 的独立包说明为历史记录。

基于 Godot 4.6.1 / GDScript 的双角色同人桌宠。使用作者手绘的魏无羡、蓝忘机素材，两个透明、置顶窗口独立行走；可拖起、落下、自然靠近和对视。当前首版目标为 Ubuntu 自用。

> 工作区新增未发布的拥抱试作：预览与运行方法见 [拥抱素材说明](assets/characters/hug/README.md)。已导出的 v0.2.2 包不包含这项试作。

> 跨平台 Stage 1：本地测试包、构建命令及验收范围见 [平台基础验证](docs/testing/STAGE1_PLATFORM_FOUNDATION.md)。Windows/macOS 导出不代表实机验收通过。

## 启动

在本仓库运行（自动使用已安装在 `.tools/` 的 Godot）：

```bash
./run.sh
```

独立 Linux 包：`dist/CPPet-v0.2.2-Linux-x64.zip`。解压后运行其中的 `./run.sh`，无需安装 Godot。若权限丢失，执行 `chmod +x run.sh CPPet.x86_64`。

需要 Linux x86_64、X11 或 XWayland、OpenGL 3.3。启动脚本显式选择 X11；开发环境为 Ubuntu 24.04、GNOME Wayland + XWayland、1920×1200、Mesa / VMware SVGA3D。源码启动也可用 `GODOT_BIN=/path/to/godot ./run.sh`。

## 操作与行为

- 左键按住人物拖动，松开后落回主显示器底部。拖动任何一方会取消双人互动。
- 右键人物：暂停／继续、回到桌面中央、退出桌宠。再次右键同一人物或拖起可关闭菜单；点击其他应用不会关闭菜单。
- 暂停时仍允许拖拽和落下。退出菜单或关闭任一窗口会结束整个进程。
- 待机 1 FPS，走路 6 FPS，对视 4 FPS。魏无羡移动 80px/s，蓝忘机 68px/s。
- 魏无羡走路／拖起使用左右独立画稿；蓝忘机共用画稿按方向翻转。
- 两人空闲、相距小于 320px、冷却结束且**魏无羡在左、蓝忘机在右**时，魏无羡走近，蓝忘机等待。随后对视、停留、播放独立的 `turn_back` 回身帧回到待机，再共同待机。反向站位不播放、不镜像。
- 魏无羡在距离最终目标还剩 40px 时切换为待机姿势，同时直接到达最终站位，不以待机姿势滑动；最终间距仍为 160px。
- 当前一次互动约 7.5 秒（靠近时间另计），结束或取消后冷却 30 秒。首版靠动作表现，不附加对白或爱心。

默认图像尺寸沿用已确认的预览：待机／对视图片高 256px，走路两人的图片等宽约 236.5px，拖起与走路共用像素缩放。保留画稿的身高差和宽高比，不改原图。不同动作的画布本身不同，因此姿态转换的体态变化仍来自原画。

```bash
./run.sh -- --debug-window  # 普通窗口调试
./run.sh -- --single        # 只显示魏无羡
./run.sh -- --paused        # 暂停自主活动启动
```

## 素材与预览

素材放在 `assets/characters/<角色>/<动作>/`，PNG 不拆身体部件。[素材入口与约定](assets/characters/README.md)。

以下场景用于单独检查素材，在 Godot 中打开后按 F6；F5 或默认启动运行真正的桌宠。

| 场景 | 用途 |
|---|---|
| `scenes/IdlePreview.tscn` | 1 FPS 待机与身高比例 |
| `scenes/WalkingPreview.tscn` | 6 FPS 走路、左右朝向、80／68px/s 移动 |
| `scenes/DragPreview.tscn` | 拖起姿势、透明命中、松手恢复 |
| `scenes/EyeContactPreview.tscn` | 4 FPS 对视、待机首帧对齐、固定左右站位 |

人物与关系依据为小说、关系确立后的稳定日常。已确认内容见 [Stage 3 记录](docs/design/STAGE3_REVIEW.md)、[文字外观要求](docs/design/VISUAL_REQUIREMENTS.md)、[参考登记表](docs/design/REFERENCE_REGISTER.md)。历史文件记录当时的制作状态；上述动作现已接入正式运行入口。

## 开发与验证

使用 Godot **4.6.1 stable 标准版**及同版导出模板，Compatibility 渲染器。`./tools/setup_godot.sh` 可准备工具链；引擎位于 `.tools/godot/`，模板位于 `.tools/templates/`。

```bash
.tools/godot/Godot_v4.6.1-stable_linux.x86_64 --headless --editor --path . --import --quit
.tools/godot/Godot_v4.6.1-stable_linux.x86_64 --headless --path . --script tests/test_runner.gd
.tools/godot/Godot_v4.6.1-stable_linux.x86_64 --headless --path . --script tests/test_app.gd
.tools/godot/Godot_v4.6.1-stable_linux.x86_64 --headless --path . --script tests/test_artwork.gd
python3 -m unittest discover -s tests -p 'test_*.py'
GODOT_BIN="$PWD/.tools/godot/Godot_v4.6.1-stable_linux.x86_64" ./tools/export_linux.sh
```

实际桌面检查：`python3 tools/desktop_smoke.py`（会在角色窗口内移动鼠标，请勿同时操作鼠标）。真实长测：`python3 tools/soak_desktop.py`；默认两小时，短测可指定 `--seconds=120`。只有结果同时包含 `status: passed` 与 `two_hour_acceptance: true` 才代表真实两小时通过。证据位于 `dist/soak-runs/`，最新索引为 `dist/soak-result.json`。`--soak` 会把空闲角色送回相遇位置以反复检查互动，普通运行不会自动传送角色。

最新实测范围及历史记录见 [VALIDATION.md](docs/VALIDATION.md)。模拟两小时不是实机两小时；旧版本的实机结论不自动适用于本次构建。

## 实现与内容

- `Pet` 共用状态机管理待机、走路、拖拽、落下、靠近、互动。
- `PetArtwork` 选择原始帧与方向，保持素材缩放／锚点，缓存透明度与轮廓。
- `DesktopWindowController` 管理 320×384 原生窗口、屏幕约束、点击穿透。
- `InteractionManager` 预约双方、控制发起／回应、同步 4 FPS 对视与共同待机、取消与冷却。
- `Main` 负责菜单、加载数据、屏幕变化恢复与诊断报告。

`data/characters.json` 定义 A=魏无羡、B=蓝忘机与移动速度；`data/interactions.json` 定义距离、站位、冷却、对视速度和时长。坏数据记录错误并禁用互动，基本活动保留。`data/dialogues.json` 当前为空，首版不需要对白。

## 发布和限制

程序包不提交到 Git，保存在同仓库的 [GitHub Releases](https://github.com/TofuPudding-w/wx_desktop_pet/releases)。本次只构建本地包；标签工作流仍创建草稿而不自动公开。见 [发布指南](docs/RELEASING.md)。

- 仅支持主显示器活动与 X11/XWayland；Windows/macOS、原生 Wayland、混合 DPI、休眠恢复、热插拔尚未全面验收。
- 鼠标穿透使用随帧更新的轮廓包络；角色外空白可穿透，轮廓内部的小孔洞可能仍拦截下面的应用。拖拽进一步按非透明像素判断。
- 大小固定；没有声音、AI、网络请求、天气、自启、自动更新或设置保存。
- 画稿来自作者手绘，未做 AI 重绘。引擎和字体许可见 [第三方说明](docs/THIRD_PARTY.md)；原创代码与美术的独立开源许可尚未指定。

### 角色大小（当前开发版）

右键任意角色 → **设置 · 角色大小** → 100%、125%、150%、175% 或 200%。两人、拥抱画面、点击区域和互动距离同步缩放，保留原始身高差，动画 FPS 不变；选择保存在本机，下次启动恢复。可用屏幕区域较小时会限制实际尺寸，以保证角色和菜单可用。原始 PNG 不修改。

这是桌宠自己的大小设置，与 Windows「设置 → 系统 → 屏幕 → 缩放」分开。Windows 额外缩放测试请记录系统缩放及桌宠大小，并重启桌宠后检查。测试步骤见 [Stage 1 检查清单](docs/testing/STAGE1_CHECKLIST.md)。

### Stage 2：日常控制（开发版）

右键 → **互动** 可选择对视／拥抱；不可用时显示原因。右键 → **设置** 可调整大小及自动互动开关，大小、暂停和自动互动状态均保存。右键 → **隐藏桌宠** 后，屏幕右侧显示白兔。右键白兔 → **显示桌宠** 手动恢复；没有倒计时。当前图标／快捷方式／隐藏流程见 [Stage 3 检查清单](docs/testing/STAGE3_CHECKLIST.md)；Stage 2 检查清单保留为历史记录。

Windows Stage 1 ZIP 实测 40.34 MiB，其中引擎 EXE 压缩后约 34.39 MiB，项目 PCK 约 5.91 MiB；新增动作主要增加资源体积，不会重复包含一份引擎。此为当前实测，不是未来版本体积保证。

Windows 包中的 `create-shortcut.cmd` 可创建带图标的桌面快捷方式；Linux 包中运行 `python3 create-shortcut.py` 创建桌面及应用菜单入口。先将便携包解压到长期保留的位置；更新或移动后重新创建快捷方式。

互动规则：对视和拥抱各自冷却 30 秒，另有 5 秒共同间隔。自动／手动一致，从完成或取消时开始；失败且未开始的请求不计入冷却。暂停和隐藏期间继续计时。

每个测试包内提供 **START_HERE.html** 离线图文指南，以及 README.txt 文字入口。指南源模板在 [docs/guide/START_HERE.template.html](docs/guide/START_HERE.template.html)，构建时自动填入平台、版本、构建编号和冷却参数。

隐藏后的白兔可按住左键拖动；位置在本次运行中保留。右键菜单会在图标附近调整位置，避免越出屏幕；右键仍可显示或退出桌宠。

右键角色 → **帮助 → 使用指南（离线）** 可打开包内 START_HERE.html。指南与图标应随完整解压目录保留；开发运行使用 dist/guide-preview/ 的预览指南。联系方式、下载网站和自动更新尚未配置。

### Stage 4：手动检查更新（开发版）

右键 → **检查更新（联网）** → **检查更新**，仅主动点击时请求版本信息；失败提示检查连接或稍后重试，不影响离线桌宠。**帮助 → 下载与更新网站** 打开同仓库 Releases。在线指南尚未配置，按钮禁用；**帮助 → 联系与反馈** 提供 3185470689@qq.com，可复制邮箱或打开邮件应用；配置入口、静态版本 JSON 及验收方法见 [Stage 4 检查清单](docs/testing/STAGE4_CHECKLIST.md)。暂不自动下载、替换或在启动时联网。当前 GitHub 单一端点不能保证大陆可用。

### 下载网站

网站文件位于 [website/index.html](website/index.html)，部署到帽子云时根目录填写 `website`，输出目录填写 `.`，无需构建命令。操作与版本更新步骤见 [部署说明](docs/website/DEPLOY.md)。当前尚无公开 Release，下载入口显示准备中；不把开发包冒充正式版。

### 菜单与网站接入

主菜单简化为：暂停／继续、互动、隐藏桌宠、设置、帮助、退出。设置包含角色大小、自动互动、重置位置、检查更新；更新面板返回设置。帮助包含使用指南（离线／在线）、访问网站、联系与反馈。

官网：https://ncecuws6h-wangxiandesktoppet-3a1n31o.maozi.io/ ，在线指南为同站 guide.html。当前环境 TLS 连接失败，尚未证实此环境可达；版本检查继续使用 GitHub，网站 version.json 在正式发布前不接入。
