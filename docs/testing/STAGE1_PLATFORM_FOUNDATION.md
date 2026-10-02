# Stage 1：跨平台基础验证

本阶段复用同一工程、同一套画稿与逻辑，准备 Linux x64、Windows x64 和 macOS Universal 2 测试包。项目版本仍为 0.2.2；测试包使用独立构建 ID，不覆盖发行包、不创建或上传 Release。

## 平台边界

- Linux 启动脚本保留 `--display-driver x11`，目标为 Ubuntu / X11 或 GNOME Wayland + XWayland。原生 Wayland 不在当前桌宠支持范围内。
- Windows 双击 CPPet.exe，使用原生 Windows 后端，不传 X11 参数。整个目录必须保留，CPPet.pck 与 EXE 放在一起。
- macOS 使用原生后端和 Universal 2 .app。当前仅构建实验包，没有 Mac 实机验收；只有内置 ad-hoc 签名，没有 Developer ID 签名／notarization，可能被 Gatekeeper 阻止。
- Windows 当前不签名、不修改系统级设置，也不是安装包。图标与快捷方式属于后续阶段。
- 菜单、设置保存、临时隐藏和更新检查都没有在本阶段新增。只有 --eye-demo 测试开关和平台诊断输出。

## 本地构建

在 Ubuntu 工程目录内：

```bash
./tools/setup_godot.sh --all-platforms
python3 tools/build_stage1.py --platform all
```

也可只构建一个目标：`--platform linux` / `windows` / `macos`。

所有模板固定 Godot 4.6.1，下载验证官方 SHA-256。构建结果在 `dist/stage1/<构建ID>/`；`dist/stage1/latest.json` 给出最新完整批次的路径。

每个包包含 BUILD_INFO.json、TEST_CHECKLIST.md、README.txt 和许可文件。记录源提交、工作区是否修改、导出输入指纹、目标系统和构建 ID；不会把未提交的工作区错误标为干净的发行提交。每个 ZIP 附带 SHA-256。

打包器验证 ZIP CRC、必需文件、Windows PE x64 / Linux ELF x64 / macOS Mach-O 双架构，以及 Unix 可执行权限。macOS 打包保留 .app 结构、权限和导出签名。构建输入在同一批次导出前后必须保持一致。

## 实机检查

参照 [STAGE1_CHECKLIST.md](STAGE1_CHECKLIST.md)。Windows 无需安装 Godot；可以分别运行 test-eye-contact.cmd 和 test-hug.cmd，避免等待随机选择。

Windows diagnose.cmd 会写入 `%LOCALAPPDATA%\WangXianPet\Stage1\pet.log` 和 telemetry.json。每次启动均记录系统、引擎、渲染后端、主屏大小／缩放和 GPU。日志是诊断信息，不是兼容性认证。

Linux 自动检查可明确指定本阶段二进制，不会误测旧发行版：

```bash
python3 tools/desktop_smoke.py --binary /absolute/path/to/stage1/CPPet.x86_64
python3 tools/soak_desktop.py --binary /absolute/path/to/stage1/CPPet.x86_64 --seconds=120
```

先关闭其他运行中的桌宠；原生检查会移动鼠标，只点击桌宠自身窗口。短测不是两小时验收。

## 阶段完成条件

- 本地自动检查、Linux 原生输入检查和测试包完整性检查通过。
- Windows 实机反馈完成透明／穿透、拖拽、焦点、对视与合并拥抱、退出、缩放和边界检查。
- macOS 如无人实测，始终标注 experimental / unverified，不计入稳定支持平台。

Windows 反馈回来前，本阶段只能称为“测试包已准备”，不能宣称跨平台验收完成。

参考：
- https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_windows.html
- https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_macos.html
- https://docs.godotengine.org/en/4.6/classes/class_displayserver.html

## 本轮 Windows 测试目标

用户确认：Windows 11、Intel x64、100% 显示缩放。其他缩放／系统版本仍需独立记录，不能由这一次结果推定。

## 完成记录（2026-10-02）

后续构建已加入并验证大小菜单及本机保存，修复边界闪烁。用户确认 Windows 全部测试通过，Stage 1 在已测试 Linux／Windows 环境完成；macOS 保持实验状态。早期“等待反馈／尚未加入设置”的文字为初始范围记录。Stage 2 开始实现互动菜单、基本设置保存及定时隐藏。
