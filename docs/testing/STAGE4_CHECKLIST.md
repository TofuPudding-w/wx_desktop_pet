# Stage 4：手动检查更新与帮助链接

这是发布准备阶段的 Stage 4；版本仍为 0.2.2 开发版。无自动替换，不发布 Release。

## 使用

角色右键 → 检查更新（联网） → 检查更新。检查时按钮禁用，可关闭菜单，结果保留到下次打开；没有启动联网、定时联网、遥测或自动下载。下载按钮始终由用户主动打开浏览器。日常活动、拖动和本地指南不需要联网。

帮助菜单提供本地指南、在线指南、下载网站、反馈入口。未配置项明确禁用；本地指南缺失时提示在线入口（若已配置），否则提示完整解压。浏览器中的联网错误由浏览器显示。

## 配置

`data/online.json`：
- `update_endpoints`：按优先级列出 HTTPS JSON 地址。每个地址最长 10 秒，失败、无效数据、非 200 均尝试下一个；不跟随重定向，使用最终 HTTPS 地址。
- `downloads_url`：项目发布页面，目前为同仓库 GitHub Releases。
- `guide_url`：可选 HTTPS 在线指南，目前空。
- `feedback_email`：公开反馈邮箱，目前为 3185470689@qq.com。帮助 → 联系与反馈可复制地址或打开邮件应用；不会自动发送邮件。`feedback_url` 为未来联系网页预留。

仓库当前为 private（作者确认），无凭证的 GitHub 仓库及发布 API 实测均为 404，公开用户暂不能检查或下载。发布前需要公开可访问的版本端点与下载目标；不向客户端嵌入私有访问凭证，不修改仓库可见性。

目前仅配置 GitHub API，不能承诺大陆可访问。准备好静态网站后，将大陆实测可达的 JSON 地址放在第一位，GitHub 作备选；下载网站统一列出 GitHub 和备用下载。源码和网站继续共用本仓库。

静态 JSON 最小格式：`{"version":"0.3.0"}`。只接受正式版三段数字（可带 v）；草稿、预发布及异常响应不会被当成正式更新。GitHub `/releases/latest` 返回的 `tag_name` 同样支持。先确认正式 Release 和各平台包可下载，再发布对应 JSON；不能将本地开发版本填成已发布版本。在线响应不能指定启动命令或下载目标，浏览器链接来自随程序发布的配置。

## 验收

1. 断网启动不报网络警告，日常行为正常。
2. 点击检查：显示检查中，不阻塞拖动；无法连接时给出可重试提示，不误报已最新。
3. 同版、较新版、旧版、非法 JSON、HTTP 403/404/500、超时分别验证。
4. 检查过程中关闭菜单、隐藏、退出，无悬空 UI 或后台残留；重新打开保留结果。
5. 在线指南未配置时按钮禁用；配置后删除本地指南，出现在线恢复提示。
6. Windows 与 Linux 默认浏览器可打开下载页面；macOS 仍为实验版，需实机检查。
7. 若有多个端点，第一端点不可达时第二端点成功；所有端点失败时不报已最新。

构建：`python3 tools/build_stage1.py --stage 4 --platform all`。
验证：`godot --headless --path . --script tests/test_updates.gd`。
参考：[Godot HTTPRequest](https://docs.godotengine.org/en/4.6/classes/class_httprequest.html)、[GitHub Releases API](https://docs.github.com/en/rest/releases/releases#get-the-latest-release)。
