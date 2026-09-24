# CP 双角色桌宠

Godot 4.6.1 / GDScript 的双人桌宠原型。蓝蓝与橙橙在桌面行走，能被拖动、落回底部，靠近后对视、显示爱心并轮流说中文对白。占位角色用代码绘制；角色参数和互动内容可修改 JSON。

## 直接运行

本地构建包：`dist/CPPet-v0.1.0-Linux-x64.zip`。线上版本统一放在[本仓库 Releases](https://github.com/TofuPudding-w/wx_desktop_pet/releases)（草稿尚不能公开下载）。解压后执行：

```bash
./run.sh
```

无需安装 Godot。需要 Linux x86_64、X11 或 XWayland、OpenGL 3.3 图形支持。启动脚本强制使用 X11 后端。当前实测环境：Ubuntu 24.04、GNOME Wayland + XWayland、1920×1200、Mesa / VMware SVGA3D。

- 左键拖拽角色，松手后落回屏幕底部；拖拽可以中断互动。
- 右键角色：暂停／继续、回到桌面中央、退出。再次右键收起菜单；拖动角色也会收起菜单。
- 暂停只停止自主行为，仍允许拖拽和落下。
- 角色相距小于 180 像素时可以互动；站位间距 110 像素，持续 4 秒，冷却 30 秒。
- 所有角色属于同一进程；任一退出按钮关闭整个程序。

```bash
./run.sh -- --debug-window   # 有边框的普通窗口，显示状态名
./run.sh -- --single         # 单角色技术验证
./run.sh -- --paused         # 暂停自主行为启动，便于检查鼠标操作
```

## 从源码开发

安装 Godot **4.6.1 stable 标准版**，不用 .NET 版，打开 `project.godot`。编辑器运行时关闭嵌入游戏，使用独立窗口；桌面运行建议使用脚本：

```bash
GODOT_BIN=/path/to/Godot_v4.6.1-stable_linux.x86_64 ./run.sh
```

运行 `./tools/setup_godot.sh` 可安装固定版本引擎和模板到被忽略的 `.tools/`。已有模板时可用 `--engine-only` 只安装引擎。导出包不依赖该开发工具目录。

### 代码结构

- `Main`：加载内容、创建两个窗口、菜单、显示区域变化检测、诊断报告。
- `Pet`：共用 `IDLE / WALK / DRAGGED / FALL / APPROACH / INTERACT` 状态机与占位绘制。
- `DesktopWindowController`：窗口属性、脚底锚点、桌面坐标、边界和输入多边形。
- `InteractionManager`：统一占用两个角色，选择互动，控制站位、超时、冷却和取消。
- `DialogueManager`：按时间顺序显示对白，取消时清理所有气泡。
- `ContentLoader`：检查内容；坏角色数据回退到默认值，坏互动禁用并打印原因。

两个 240×240 原生窗口，统一脚底锚点 `(120,232)`。角色高度约 128 像素。角色窗口之外、窗口两侧空白处不拦截点击；气泡和菜单出现时扩展输入区域。点击区域为近似几何轮廓，不是每帧按透明像素取样。

所有位置以主显示器可用区域为准，每秒检查一次；显示布局变化后取消互动、约束位置并落回底部。自主行走不会抢键盘焦点。渲染上限 30 FPS，长帧的行为步长被限制，避免休眠恢复时突然跨屏跳跃。

### 修改内容

`data/characters.json`：固定顺序 A、B，字段 `id`、`name`、HTML `color`、正数 `walk_speed`。

`data/interactions.json`：互动 ID 映射到正数 `weight`、`trigger_distance`、`spacing`、`cooldown`、`duration`、`approach_timeout`，以及对白 ID `dialogue`。距离单位为像素，时间单位为秒。当前只提供对视／爱心这一种表演；增加 JSON 条目仅增加这类表演的内容变体，不会自动创造新动画。

`data/dialogues.json`：对白 ID 对应数组，元素为 `speaker`（A 或 B）和 `text`。首版固定气泡，一句最多 11 字。未来接入逐帧素材时保留统一脚底与双人站位。

## 检查与导出

运行自动测试（含模拟两小时的状态机压力测试）：

```bash
/path/to/godot --headless --editor --path . --import --quit
/path/to/godot --headless --path . --script tests/test_runner.gd
/path/to/godot --headless --path . --script tests/test_app.gd
```

真实桌面两小时挂机，与上面的模拟测试不同：

```bash
./run.sh -- --soak --quit-after=7200 --telemetry=/tmp/cp-pet-soak.json
# 或对独立包运行自动判定及 RSS 记录：
python3 tools/soak_desktop.py
```

`--soak` 会把空闲角色送回相遇位置，反复验证完整互动，不模拟鼠标。每 30 秒覆盖写入报告，包含已运行秒数、完成／取消次数、状态和 Godot 管理的内存；两小时后自动退出。普通启动没有这个行为。鼠标命中探针 `tools/x11_probe.py` 需要 X11 的 libX11、libXext、libXtst、xwininfo、ImageMagick；它会移动鼠标并点击桌宠，运行时请不要同时操作鼠标。

下载官方 **4.6.1 stable** 的 `Godot_v4.6.1-stable_export_templates.tpz`，将 `templates/linux_release.x86_64` 和 `templates/linux_debug.x86_64` 提取到 `.tools/templates/`。本次已准备好这两个模板。引擎与模板必须同版本。

```bash
GODOT_BIN=/path/to/godot ./tools/export_linux.sh
```

输出 `dist/CPPet-v0.1.0-Linux-x64/`、ZIP 和 SHA-256 文件。资源嵌入可执行文件，测试文件不进入包；附带启动脚本、中文说明和第三方许可证。构建依赖 Python 3，不需要额外 Python 库。

## GitHub Releases

推送 `vX.Y.Z` 标签后，工作流自动测试、构建 Linux ZIP 并上传到同仓库的 Release 草稿；不会自动公开。版本必须与 `project.godot` 一致，发布说明位于 `releases/vX.Y.Z.md`。程序包不提交到 Git。

完整操作、重试与下载链接说明见 [发布指南](docs/RELEASING.md)。目前只提供 Linux，Windows/macOS 适配和静态网站留待后续。

## 已知限制

- 原生 Wayland 不支持本原型所需的定位与局部点击穿透；使用 XWayland。依据：[Godot DisplayServer](https://docs.godotengine.org/en/4.6/classes/class_displayserver.html#class-displayserver-method-window-set-position)。
- 仅主显示器活动；混合 DPI、屏幕热插拔、真实休眠恢复仍需人工实机验收。固定像素大小，尚无大小设置。
- 没有音效、AI、网络请求、自启、设置持久化、正式 CP 素材或 Windows 发行包。
- 菜单通过再次右键或拖拽关闭；点击其他应用不会自动关闭菜单，避免监听其他应用输入。
- 测试记录见 `docs/VALIDATION.md`。模拟时间不能替代真实两小时挂机。

字体、Godot 及其依赖的许可见 `docs/THIRD_PARTY.md`；项目原始代码的开源许可证尚待作者选择。
