# 角色动画素材入口

运行素材统一放这里；`docs/design/` 保留设计文档和参考图，不用于程序读取（该目录有 `.gdignore`）。

```text
assets/characters/
├── wei_wuxian/
│   └── idle/
│       ├── 01.png
│       ├── 02.png
│       ├── idle.tres    # SpriteFrames：1 FPS，两帧循环 2 秒
│       └── Idle.tscn    # 共同缩放、画布底边对齐的可复用场景
├── lan_wangji/
│   └── idle/           # 同样结构
└── idle_alignment.json # 原图尺寸、透明边界、缩放及原始哈希记录
```

走路帧按已提供的结构放 `walking/left_to_right/1.png`、`walking/right_to_left/1.png` 等；被拖起可放 `dragged/01.png`。PNG 按数字编号的播放顺序排列；每个动作内保持画布与脚底位置一致。Procreate 可编辑工程自行保存；这里放透明 PNG 导出帧。

四张 PNG 从 `docs/design/standby/` 原样迁入，未重绘、裁切或重采样。两人的图片高度都是 713px；Godot 对所有帧统一使用 `128 / 713` 的等比显示缩放，让整张图片显示为 128px 高，保留人物原本的高矮差、宽高比和留白。不再按人物轮廓分别缩放到等高。

两人的场景原点都位于原图画布底边的水平中心，所有帧使用共同缩放。原图脚底与底边之间的细微差异也保留，不单独移动人物。1 FPS 不变，不附加代码晃动。以后继续使用一致的画布高度与定位；若要整体放大，在两人共同父节点上统一调整，不能分别按人物轮廓归一化。若原图画布尺寸改变，需要同步更新场景配置。

在 Godot 打开 `scenes/IdlePreview.tscn`，按 F6 预览两人并排。预览对两个角色统一放大 2 倍（图片显示高度 256px，使用平滑过滤），保留身高差；原图和可复用素材场景不变。灰底、名字和横线仅用于检查素材，并非最终桌宠界面。命令行也可以运行：

```bash
.tools/godot/Godot_v4.6.1-stable_linux.x86_64 --path . --display-driver x11 res://scenes/IdlePreview.tscn
```

本次交付待机素材、对齐场景和独立预览。默认桌宠仍是已验收的蓝橙原型；尚未把新人物接入行走、拖拽或双人互动。素材是用户提供的手绘作品，没有使用 AI 重绘。

## 魏无羡双方向走路

已接收 `wei_wuxian/walking/left_to_right/` 和 `right_to_left/`，沿用用户目录与数字文件名；每方向 8 帧、6 FPS，禁止水平镜像。详见 [走路素材说明](wei_wuxian/walking/README.md)。打开 `scenes/WalkingPreview.tscn` 按 F6 查看图片高 256px 的双方向预览。

## 蓝忘机走路与双人等宽预览

已接入 `lan_wangji/walking/1.png`～`4.png`，暂沿用 6 FPS，用户允许左右共用并镜像。两人走路原图宽度同为 631px，使用完全相同缩放；预览图片等宽约 236.5px，保留不同图片高度。打开 `scenes/WalkingPreview.tscn` 按 F6 可看双人实际走动。详见 [蓝忘机走路说明](lan_wangji/walking/README.md)。待机规格不变。
