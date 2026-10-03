# v0.3.0 发布流程

使用现有仓库，Linux x64、Windows x64、实验 macOS Universal 共三个 ZIP 和各自 SHA-256。标签工作流创建 draft=true / prerelease=true，不公开、不设为 latest，不覆盖已有资产。

版本来源 project.godot；发布说明 releases/vX.Y.Z.md。准备后运行 Python 全部检查和 Godot 行为／布局检查，提交代码、推送 main，再推送不可移动的 vX.Y.Z 标签。Actions 从该提交安装固定 Godot 4.6.1 全平台模板，测试、导出并校验三个包，用内置 GITHUB_TOKEN 上传草稿。

本地：`python3 tools/build_stage1.py --stage 4 --release --platform all`。输出 dist/releases/vX.Y.Z/；同路径已有构建时拒绝覆盖。检查包内 BUILD_INFO.json、RELEASE_NOTES.md、START_HERE.html、README.txt 与启动助手。构建产物不进入 Git。

检查草稿附件后才公开。macOS 标为实验、未实机验证，Windows 需最终包复测；不能把历史长测计为新包长测。预发布不被当前稳定通道更新检查器提示。

网站发布后仍暂时显示准备中，直到 Release 真正公开。随后再写入真实可下载链接；官网 version.json 只宣布稳定版本，不能把预发布误报为稳定版。当前网站生成器只支持稳定发布元数据，公开预览下载时需将预览下载展示与稳定更新信息分开。

自动部署的网站以推送的 website/ 为准；修改模板后先运行 python3 tools/build_website.py。本次不在网站写入草稿下载链接。
