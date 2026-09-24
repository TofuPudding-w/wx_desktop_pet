# GitHub Releases 发布流程

使用现有仓库 `TofuPudding-w/wx_desktop_pet`，源码与发布配置在一起。本站点开发尚未开始；不启用 GitHub Pages 或 Cloudflare。`docs/` 继续保留现有说明与预览图。

## 当前发布范围

- Linux x86_64：已有原型构建，发布 ZIP 和 SHA-256 校验文件。
- Windows / macOS：本次不构建、不上传，也不提供无效下载链接。适配和实机验收后再给同一工作流增加对应构建任务。
- 每个版本使用 `vX.Y.Z` 标签；`project.godot` 的 `config/version` 是版本来源。
- 自动化只创建 **draft=true / prerelease=true** 的草稿。不会公开、不会设为 latest，也不会修改已公开的 Release。
- 不需要往仓库保存个人令牌。上传任务使用 GitHub Actions 自动提供的 `GITHUB_TOKEN`，仅该任务有 `contents: write`。

## 发布一个版本

1. 修改 `project.godot` 的版本，例如 `0.1.1`；更新相应验证记录。
2. 新建 `releases/v0.1.1.md`，写明功能、已测平台、已知限制及运行方法。保留“同人作品，非商业，仅供爱好者个人使用”的定位说明。
3. 提交源码与说明，推送到现有仓库的主分支，再创建标签：

```bash
git push origin main
git tag -a v0.1.1 -m "CP 桌宠 v0.1.1"
git push origin v0.1.1
```

先推主分支、再推标签，保证发布目标已包含在默认分支中。不要移动或强推已经发布的标签。

4. 打开 [Release draft 工作流](https://github.com/TofuPudding-w/wx_desktop_pet/actions/workflows/release.yml)。它会校验标签／版本／发布说明，检查源码提交，下载校验过的 Godot 4.6.1 引擎和同版本模板，运行 Python 发布测试和 Godot 无界面测试，然后导出 ZIP。
5. 构建产物暂存为 Actions artifact（保留 7 天）；第二个任务从相同提交创建草稿，将 ZIP 与 `.zip.sha256` 上传到 **Release Assets**。草稿资产不依赖临时 artifact 的保留期限。
6. 在 [Releases](https://github.com/TofuPudding-w/wx_desktop_pet/releases) 中检查草稿说明与两个附件。你决定公开时，再点击 GitHub 的 **Publish release**；本次不会替你执行这一步。

默认分支上的工作流也支持 **Run workflow**：输入已有标签，重新运行失败的任务。不支持把未打标签的工作目录直接发布。

## 下载与链接

以 v0.1.0 为例，公开后对应链接为：

```text
https://github.com/TofuPudding-w/wx_desktop_pet/releases/download/v0.1.0/CPPet-v0.1.0-Linux-x64.zip
https://github.com/TofuPudding-w/wx_desktop_pet/releases/download/v0.1.0/CPPet-v0.1.0-Linux-x64.zip.sha256
```

这些是**公开发布后**的链接格式，草稿阶段不能作为公众下载地址。私有仓库的 Releases 也受仓库访问权限限制；创建 Release 不会改变仓库可见性。

本项目包名包含版本号，而且当前是预发布；不要直接套用 `releases/latest/download/固定文件名`。未来网站可读取 Releases 列表或使用明确的版本链接，本次不制作网站。

GitHub 自动显示的 Source code ZIP / tar.gz 是源码归档，不是安装包。真正给用户下载的是上传到 Assets 的平台 ZIP。

## 本地构建和检查

```bash
./tools/setup_godot.sh
GODOT_BIN="$PWD/.tools/godot/Godot_v4.6.1-stable_linux.x86_64" ./tools/export_linux.sh
python3 -m unittest discover -s tests -p 'test_release*.py' -v
```

首次完整安装工具链会下载约 68 MB 的引擎与约 1.2 GB 的全平台模板压缩包，只提取 Linux 模板。文件留在被忽略的 `.tools/`，后续校验并复用缓存。若 Linux 模板已经准备好，`./tools/setup_godot.sh --engine-only` 只安装引擎。

打包文件清单固定、ZIP 时间戳固定、执行权限固定；相同文件内容产生相同 ZIP。只打包明确列出的程序／说明／许可证，不会顺手把日志或临时文件放进包里。

## 失败与重试

- 标签与项目版本不同或缺少发布说明：在下载大文件前失败；修正源码并使用对应新标签。
- 测试失败或构建失败：不会运行草稿创建任务。查看 Actions 日志；无界面测试不等于通过所有桌面兼容性验收。
- 同版本草稿已存在：摘要相同的附件会跳过，缺少的附件继续上传。若同名附件内容不同，停止并要求人工核对，不覆盖它。
- 上传中断：草稿可能保留已上传附件。检查失败资产后再重试；不要公开附件不完整的草稿。
- Release 已公开：流程拒绝修改它。修复应使用新版本和新标签。
- Actions 被禁用或仓库权限受限：需在 GitHub 仓库设置中允许运行工作流。不要把 token 写入脚本或提交到 Git。

Git 不跟踪 `dist/`、`.tools/` 或 ZIP、DMG、AppImage、EXE 等发布文件；字体等必要源码资源仍正常跟踪。可运行 `git check-ignore dist/example.zip` 检查。

参考：[GitHub 发布管理](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository)、[GITHUB_TOKEN](https://docs.github.com/en/actions/tutorials/authenticate-with-github_token)。
