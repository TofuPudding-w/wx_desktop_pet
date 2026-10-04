# 帽子云部署

网站位于现有仓库 website/，纯 HTML/CSS/JS；所有资源本地提供，没有运行时 GitHub API 请求、外部字体或统计。作者原图只复制，不修改。

创建应用填写：

- 仓库：TofuPudding-w/wx_desktop_pet
- 分支：main
- 根目录：website
- 构建命令：留空（已生成静态文件，无需 npm）
- 输出目录：.（相对于 website）
- 环境变量：无需

先将网站文件及相关生成工具提交、推送到 main，帽子云才可读取本地新增内容。只部署 website/，不要发布仓库根目录或 docs/。

纯静态配置以控制台实际校验为准；如果必须填写构建命令，可用 `echo static-site-ready`，输出目录仍为 `.`。官方说明：https://www.maoziyun.com/docs/deploy/build

## 当前发布状态

仓库已公开。2026-10-03 查询公共 Releases API 返回空数组；不把本地开发构建或草稿作为已公开版本。下载按钮因此标记准备中。version.json 为 `{"version":null,"status":"unreleased"}`，有意不宣布不存在的稳定版本；正式发布前不要将此地址接入桌宠更新端点。

## 更新网站

1. 先公开 Release 并确认安装包可下载；把相同文件上传国内备用来源，验证匿名下载。
2. 编辑 docs/website/release.json，填写正式版本、日期、更新说明及每个平台的真实链接。不存在的平台保持空，不伪造下载。
3. 运行 `python3 tools/build_website.py`，会同步生成主页、指南和 version.json。后者正式发布后包含可供现有桌宠读取的三段数字 version。
4. 检查页面，提交生成文件和元数据，推送部署。不能只编辑 website/version.json 导致页面版本不同步。
5. 从大陆网络测试首页、guide.html、version.json 和下载源。页面可达不代表 GitHub 下载也可达。
6. 获得真实 HTTPS 域名后，再修改 data/online.json：update_endpoints 首位放最终直达 /version.json 地址，downloads_url 指向首页，guide_url 指向 /guide.html。当前程序不跟随版本请求重定向，必须填写最终地址。配置变更需重新打包桌宠。

本地预览：`python3 -m http.server 8765 --bind 127.0.0.1 --directory website`，打开 http://127.0.0.1:8765/。

指南来自现有 docs/guide/START_HERE.template.html；手绘待机两帧保持同画布高度及原始比例，1 FPS。减少动态效果的系统偏好会停止动画，按钮可手动暂停。原始素材不变。

## 本次验证

37 项 Python 检查通过，包括站内链接／锚点、版本信息一致性、危险下载链接拒绝、原始素材逐字节一致。Firefox 已检查桌面 1440px 与手机 390px 布局；已修正手机角色预览裁切。网站图片与 Godot 导出分离，避免增加桌宠安装包体积。未提交、推送或部署。

## 公开预览版下载（v0.3.0）

GitHub v0.3.0 已于 2026-10-03 公开为 pre-release。release.json 的 version/date/downloads 用于下载页面；prerelease=true 显示「公开预览版」。stable_version=null 表示尚无稳定版，网站 version.json 不会将预览版推送到稳定更新通道。以后发布新预览版时应保留已有真实 stable_version；发布正式版则设 prerelease=false。国内备用链接仍为空，不能将 GitHub 链接当成国内镜像。

## 百度网盘备用下载

三个平台按钮共用作者提供的分享文件夹；release.json 各平台 mainland 为分享链接，mainland_label 为「百度网盘下载」，mainland_code 为「wx99」。网页展示提取码，提示用户自行选择对应系统 ZIP。分享内容由作者维护，未通过自动检查核验网盘内文件与 Release 的校验和一致。
