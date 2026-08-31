# AGENTS.md

## 项目简介

ArtShelf —— macOS 原生个人媒体策展应用（影视 / 音乐 / 书籍），100% 本地优先，零云端、无遥测。

当前处于 **v3 全面重构阶段**：产品方向为「沉浸暗房」（封面即主角、深色沉浸、深浅双色随系统切换），在本仓库 `redesign/v3` 分支上从零重建。

## 仓库当前状态（v3 重构期）

- 工作分支：`redesign/v3`（从 `main` 切出）
- `ArtShelf/` 目录下已是 **v3 新代码**（沉浸暗房，深浅双色随系统，JSON 数据层）；v2 旧版（象牙纸画廊风，版本 2.0.2）已封存于提交 `7bc21d3`，可用 `git show 7bc21d3:<路径>` 查阅参考
- 产品设计定稿：`docs/product-design.md`（先读这个）
- 技术方案定稿：`docs/tech-architecture.md`（Swift 6 + SwiftUI + JSON 存储，零第三方依赖）
- 视觉概念稿：`design-proposals/index.html`（浏览器直接打开；地址栏加 `#light` / `#dark` 可强制预览两种外观）

## 构建与运行

```bash
./build.sh          # 一键编译 release、打包 ArtShelf.app 并安装到 /Applications
cd ArtShelf && swift build    # 仅编译（调试）
cd ArtShelf && swift run ArtShelf --self-test   # 内置数据层自测（仅 Debug 构建）
```

要求：macOS 14.0+（部署目标），Xcode 命令行工具或完整 Xcode，Swift 6 工具链。

注意：本机仅有 Command Line Tools（无完整 Xcode）时，构建前需 `export SDKROOT="$(xcrun --show-sdk-path)"`；XCTest 不可用，测试以 `--self-test` 内置自测进行（`Sources/ArtShelf/SelfTest/`）。

## 工程约定

- **零第三方依赖**：纯 Swift + 系统框架（SwiftUI / AppKit / Foundation）。新增任何依赖前先讨论
- **数据边界**：用户数据只存于本机 `~/Library/Application Support/ArtShelf/`；仓库中绝不提交真实收藏数据、封面缓存或笔记内容
- **设计令牌**：颜色 / 字体 / 间距 / 圆角统一定义在 `ArtShelf/Sources/ArtShelf/DesignSystem/Theme.swift`（深浅两套），视图里禁止散落硬编码色值
- **文案与注释**：UI 文案与代码注释使用简体中文；标识符、类型名使用英文
- **提交信息**：Conventional Commits + 中文描述（如 `feat: 新增…` / `chore: …` / `docs: …`）

## 目录结构

```
ArtShelf/
├── build.sh                    # 构建、打包与安装脚本
├── docs/                       # 产品与技术文档、截图
├── design-proposals/           # v3 视觉概念稿（HTML）
└── ArtShelf/                   # Swift Package（v3 代码）
    ├── Package.swift
    ├── Resources/              # Info.plist、图标资源
    ├── Scripts/                # 图标生成/打包脚本
    └── Sources/ArtShelf/
        ├── main.swift          # 入口（含 --self-test 自测分支，仅 Debug）
        ├── ArtShelfApp.swift   # 窗口配置、菜单命令与快捷键
        ├── DesignSystem/       # 设计令牌（深浅双色）、封面加载与取色、通用组件
        ├── Models/             # Codable 值类型（MediaItem / NoteEntry / 枚举）
        ├── Services/           # 元数据抓取、EPUB 解析、文件与链接打开
        ├── Store/              # LibraryStore 仓库、v2→v3 迁移器、导入导出
        ├── SelfTest/           # 内置数据层自测（仅 Debug 构建）
        └── Features/           # 按页面组织视图（Root/Now/Library/Detail/Add/Stats/Settings）
```
