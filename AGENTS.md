# AGENTS.md

## 项目简介

ArtShelf —— macOS 原生个人媒体策展应用（影视 / 音乐 / 书籍），100% 本地优先，零云端、无遥测。当前版本 **v3.2.9**（沉浸暗房：封面即主角、白昼与暗房主题、图标动态切换、JSON 数据层）。

## 构建与运行

```bash
./build.sh          # 一键编译 release、打包 ArtShelf.app 并安装到 /Applications
cd ArtShelf && swift build    # 仅编译（调试）
cd ArtShelf && swift run ArtShelf --self-test        # 内置数据层自测（仅 Debug 构建）
cd ArtShelf && swift run ArtShelf --render-preview <目录>  # 离屏渲染各页面 PNG（仅 Debug，演示数据，供无截屏权限环境做视觉对照）
```

要求：macOS 14.0+（部署目标），Xcode 命令行工具或完整 Xcode，Swift 6 工具链。

注意：本机仅有 Command Line Tools（无完整 Xcode）时，构建前需 `export SDKROOT="$(xcrun --show-sdk-path)"`；XCTest 与 `#Preview` 宏不可用（宏插件缺失，代码中勿用），测试以 `--self-test` 内置自测进行；改动数据层行为时同步补自测断言。

## 工程约定

- **零第三方依赖**：纯 Swift + 系统框架（SwiftUI / AppKit / Foundation）。新增任何依赖前先讨论
- **数据边界**：用户数据只存于本机 `~/Library/Application Support/ArtShelf/`；仓库中绝不提交真实收藏数据、封面缓存或笔记内容（README 截图等一律用 `--render-preview` 演示数据渲染图）
- **设计令牌**：颜色 / 字体 / 间距 / 圆角统一定义在 `ArtShelf/Sources/ArtShelf/DesignSystem/Theme.swift`，调色板按外观主题组织（`ThemeSettings.swift` 的 `ThemePalette`），视图里禁止散落硬编码色值
- **状态流转收口**：状态与进度的副作用一律经 `LibraryStore` 方法（`startTasting` / `finish` / `replay` / `updateProgress` / `setTotal` / `switchProgressUnit` / `markTasted`），视图不直接改状态字段；流转规则见 `docs/product-design.md` §6
- **文案与注释**：UI 文案与代码注释使用简体中文；标识符、类型名使用英文
- **提交信息**：Conventional Commits + 中文描述（如 `feat: 新增…` / `chore: …` / `docs: …`）
- **版本递进**：版本号三段 `大.中.小`，按更新性质递增——大版本：整体重构 / 方向性变更；中版本：新功能；小版本：修复与小调整。改 `Resources/Info.plist` 的 `CFBundleShortVersionString`，同时 `CFBundleVersion` 整数 +1，README 徽章、`SettingsView` 兜底版本号、AGENTS.md 项目简介三处同步；功能更新完成即提交 git

## 目录结构

```
ArtShelf/
├── build.sh                    # 构建、打包与安装脚本
├── docs/                       # 产品与技术文档、截图
├── design-proposals/           # v3 视觉概念稿（HTML）
└── ArtShelf/                   # Swift Package
    ├── Package.swift
    ├── Resources/              # Info.plist、图标资源
    ├── Scripts/                # 图标生成/打包脚本
    └── Sources/ArtShelf/
        ├── main.swift          # 入口（--self-test / --render-preview 分支，仅 Debug）
        ├── ArtShelfApp.swift   # 窗口配置、菜单命令与快捷键
        ├── DesignSystem/       # 设计令牌（外观主题与琥珀强调色）、封面加载与取色、应用图标切换、通用组件
        ├── Models/             # Codable 值类型（MediaItem / NoteEntry / 枚举）
        ├── Services/           # 元数据抓取（豆瓣/维基/Wikidata/iTunes/TVMaze/Google Books）、EPUB 解析、文件与链接打开
        ├── Store/              # LibraryStore 仓库、v2→v3 迁移器（含资料链接归位）、导入导出
        ├── SelfTest/           # 内置数据层自测与离屏预览渲染（仅 Debug 构建）
        └── Features/           # 按页面组织视图（Root/Now/Library/Detail/Add/Stats/Settings）
```

## 文档

- `docs/product-design.md` —— 产品设计定稿（定位、页面、视觉系统、数据口径），先读这个
- `docs/tech-architecture.md` —— 技术方案（分层、数据层、迁移、设计系统实现）
- `design-proposals/index.html` —— 视觉概念稿（浏览器直接打开，`#light` / `#dark` 强制预览）
