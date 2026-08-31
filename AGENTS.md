# AGENTS.md

## 项目简介

ArtShelf —— macOS 原生个人媒体策展应用（影视 / 音乐 / 书籍），100% 本地优先，零云端、无遥测。

当前处于 **v3 全面重构阶段**：产品方向为「沉浸暗房」（封面即主角、深色沉浸、深浅双色随系统切换），在本仓库 `redesign/v3` 分支上从零重建。

## 仓库当前状态（v3 重构期）

- 工作分支：`redesign/v3`（从 `main` 切出）
- `ArtShelf/` 目录下是 **v2 旧版代码**（象牙纸画廊风 + 拟物封面，版本 2.0.2），在 v3 落地前保留作参考，新代码将逐步替换它
- 产品设计定稿：`docs/product-design.md`（先读这个）
- 技术方案定稿：`docs/tech-architecture.md`（Swift 6 + SwiftUI + SwiftData，零第三方依赖）
- 视觉概念稿：`design-proposals/index.html`（浏览器直接打开；地址栏加 `#light` / `#dark` 可强制预览两种外观）

## 构建与运行

```bash
./build.sh          # 一键编译 release、打包 ArtShelf.app 并安装到 /Applications
cd ArtShelf && swift build    # 仅编译（调试）
```

要求：macOS 14.0+（部署目标），Xcode 命令行工具或完整 Xcode，Swift 6 工具链。

## 工程约定

- **零第三方依赖**：纯 Swift + 系统框架（SwiftUI / AppKit / Foundation）。新增任何依赖前先讨论
- **数据边界**：用户数据只存于本机 `~/Library/Application Support/ArtShelf/`；仓库中绝不提交真实收藏数据、封面缓存或笔记内容
- **设计令牌**：颜色 / 字体 / 间距 / 圆角统一定义在样式令牌中（v2 为 `ArtShelf/Sources/ArtShelf/Views/ArtShelfStyle.swift`），视图里禁止散落硬编码色值；v3 令牌需同时提供深浅两套
- **文案与注释**：UI 文案与代码注释使用简体中文；标识符、类型名使用英文
- **提交信息**：Conventional Commits + 中文描述（如 `feat: 新增…` / `chore: …` / `docs: …`）

## 目录结构

```
ArtShelf/
├── build.sh                    # 构建、打包与安装脚本
├── docs/                       # 产品与技术文档、截图
├── design-proposals/           # v3 视觉概念稿（HTML）
└── ArtShelf/                   # Swift Package（v2 代码，v3 重建中）
    ├── Package.swift
    ├── Resources/              # Info.plist、图标资源
    ├── Scripts/                # 图标生成/打包脚本
    └── Sources/ArtShelf/
        ├── Models/             # 数据模型
        ├── Services/           # 元数据抓取、EPUB 解析、封面缓存
        ├── Store/              # 持久化与主题管理
        └── Views/              # SwiftUI 视图层
```
