# ArtShelf v3 技术方案

> 状态：已定稿（2026-08-31 讨论确认）；2026-08-31 修订：数据持久层由 SwiftData 改为 JSON 文件存储（见 §3.0）
> 配套文档：`docs/product-design.md`（产品设计，先读）

---

## 1. 技术栈定案

| 项 | 定案 | 说明 |
| :-- | :-- | :-- |
| 语言 / 工具链 | Swift 6.2，语言模式 Swift 6 | 全新代码，从第一天开启严格并发检查 |
| UI 框架 | SwiftUI（按需下探 AppKit） | 窗口质感、毛玻璃、系统外观跟随均为原生 |
| 数据持久层 | **JSON 文件存储**（Codable 值类型 + `@Observable` 仓库，防抖落盘） | 存储格式即导出线格式，数据透明承诺最直接 |
| 平台 / 部署目标 | macOS 14.0+，仅 macOS | 不预留 iOS |
| 工程形态 | Swift Package 单一 executable target | 目录分层代替多模块拆分 |
| 第三方依赖 | **零**（纯系统框架） | 新增依赖需先讨论 |
| 测试 | 内置自测 `swift run ArtShelf --self-test`（迁移器 / 仓库流转 / 进度计算） | 本机仅有 Command Line Tools，无 XCTest；自测仅 Debug 构建包含 |
| 构建发布 | `build.sh`（保留沿用） | 版本号升至 3.0.0（M6 收尾时） |

### 为什么不用跨平台方案

Tauri / Electron / Flutter 在没有跨平台需求的前提下，只会牺牲原生质感（窗口、外观跟随、快捷键体系）换不到收益。概念稿中的所有视觉效果 SwiftUI 均可原生实现。

### 为什么不拆多模块 SPM

一人项目、万行级代码量，编译时间不是瓶颈。单 target + 严格目录分层足够，避免模块边界的维护税。

## 2. 代码分层

单 target 内按目录强制分层，依赖方向自上而下，禁止反向引用：

```
Sources/ArtShelf/
├── main.swift               # 入口（--self-test 自测分支，仅 Debug）
├── ArtShelfApp.swift        # 窗口配置、菜单命令与快捷键
├── DesignSystem/            # 设计令牌（深浅双色）、封面加载与取色、光效组件
├── Models/                  # Codable 值类型（MediaItem / NoteEntry / 枚举）
├── Services/                # 元数据抓取、EPUB 解析、文件与链接打开
├── Store/                   # LibraryStore 仓库、迁移器、导入导出、路径约定
├── SelfTest/                # 内置数据层自测（仅 Debug 构建）
└── Features/                # 按页面组织视图
    ├── Root/                # 外壳：顶栏、全局搜索、详情导航、Esc 分层
    ├── Now/                 # 「此刻」首页（Hero / 队列 / 精选 / 数据条）
    ├── Library/             # 片库 / 唱片 / 书架 网格页
    ├── Detail/              # 沉浸详情
    ├── Add/                 # 收录流程
    ├── Stats/               # 统计
    └── Settings/            # 设置
```

## 3. 数据层设计

### 3.0 为什么弃用 SwiftData（2026-08-31 修订）

原方案定为 SwiftData，实施时发现构建机**仅有 Command Line Tools、无完整 Xcode**，宏插件缺失导致 `@Model` 无法编译。重新评估后改回 JSON：

- JSON 正是 v2 已验证的存储方式，且与「数据透明、用户可自查」的产品承诺完全一致
- 存储格式与导入导出线格式统一为同一 `LibraryDocument`，省掉 DTO 双向映射
- 个人媒体库量级（千条以内）下，内存全量 + 防抖落盘性能绰绰有余

### 3.1 模型与仓库

- `MediaItem`（Codable struct）：标题、创作者、年份、类型（影视/音乐/书籍）、简介、标签、评分、状态、封面本地路径、关联文件路径、外部链接、添加时间、最近浏览时间、**最近品味时间 `lastTastedAt`**、**进度 `progressCurrent` / `progressTotal`（Int 对）**（影视=分钟、书籍=页、音乐=音轨，折算 0–1 展示）、**重温次数 `replayCount`**、手记数组
- `NoteEntry`（Codable struct）：创建时间、正文。策展手记条目化，按时间倒序
- `LibraryStore`（`@MainActor @Observable`）：内存全量持有 `items`（只读），所有修改经仓库方法执行并 **0.5s 防抖落盘**（退出时 flush）；解码器容错兼容 v2 字段（如单条笔记字符串 → `[NoteEntry]`）

存储位置：`~/Library/Application Support/ArtShelf/library.json`（带 `schemaVersion: 3`），与既有 `covers/` 目录并列。

**状态流转副作用统一收口在 Store 层**（`startTasting` / `finish` / `replay` / `updateProgress` 方法），视图不直接改状态字段；流转规则见 `product-design.md` §6。

### 3.2 JSON 导入导出

- `LibraryDocument`（Codable，带 `schemaVersion: 3`）**既是存储格式也是导出线格式**
- 设置面板提供「导出 JSON / 从 JSON 导入」（`Store/LibraryIO.swift`，NSSavePanel / NSOpenPanel）

### 3.3 v2 → v3 迁移

首次启动检测 `library.json`（v2 格式）：

1. 备份原文件为 `library.v2.backup.json`（永不覆盖）
2. 按字段映射解析（新字段给默认值：`progressCurrent/Total = 0`，`replayCount = 0`，v2 单条笔记转为一条 `NoteEntry`，进行中藏品 `lastTastedAt` 回落到最近浏览时间）
3. 立即落盘为 v3 格式；`covers/` 封面目录原样沿用（文件名约定不变）
4. 文件损坏则备份为 `library.json.corrupt-<时间戳>` 并置 `loadFailed` 由 UI 提示，不碰原文件

迁移器由内置自测覆盖（构造 v2 样本 JSON → 断言字段映射、默认值与备份行为）。

## 4. 设计系统实现

- **语义令牌**：`DesignSystem/Theme.swift` 以代码定义 `dynamic(light:dark:)` 颜色（沿用 v2 `ArtShelfStyle` 的 NSColor 动态色手法），令牌口径与 `product-design.md` §5.1 表格一一对应
- **外观跟随系统**：不手动管理主题，直接依赖系统外观；深浅两套令牌自动生效（v3 首期不提供手动切换）
- **封面主色光晕**：`DesignSystem/NSImage+AverageColor.swift`——`CIAreaAverage` 降采样取主色；视图按令牌强度渲染光晕
- **Hero 环境渲染**：封面图放大 + `.blur(radius:)` + 径向渐变叠色，浅色模式不透明度 0.5（令牌 `amb`）
- **字体**：系统字体栈，不设自定义字体

## 5. 既有服务迁移（逻辑原样搬运，接口现代化）

| v2 文件 | 处置 |
| :-- | :-- |
| `MetadataService.swift` | 保留多源抓取逻辑（Wikipedia/TVMaze/Apple/iTunes/Google Books），统一为 async/await，零 API Key 不变 |
| `EPUBService.swift` | 原样迁移 EPUB 解包取封面逻辑 |
| `ImageCache.swift` | 不整体移植；封面下载与内存缓存由 `DesignSystem/CoverImageView.swift` 内 `CoverImageLoader`（NSCache）承担，落盘沿用 `covers/` 目录约定 |
| `FileService.swift` / `LinkMetadataService.swift` | 原样迁移 |
| `ThemeManager.swift` | **废弃**，由 DesignSystem 令牌 + 系统外观取代 |
| `DataStore.swift` | **废弃**，由 `LibraryStore`（内存全量 + JSON 防抖落盘）取代 |
| 三个拟物封面视图（`MovieCoverView` / `MusicCoverView` / `BookCoverView`） | **废弃**，v3 为平铺封面 + 光效 |

## 6. 窗口与交互

- SwiftUI `Window` 场景单窗口；隐藏工具栏标题，顶栏自绘（Tab / 搜索 / 收录按钮）
- 菜单命令：`.commands` 注册 `⌘1`–`⌘5` 切 Tab、`⌘N` 收录、`⌘F` 聚焦搜索
- 详情由 v2 的弹窗改为整版页面（导航栈内切换）；`Esc` 分层关闭（搜索浮层 → 详情 → 收录）

## 7. 里程碑

| 里程碑 | 内容 | 验收 |
| :-- | :-- | :-- |
| M1 骨架 | 工程清理、Swift 6 模式、DesignSystem 令牌、JSON 模型与仓库、v2→v3 迁移器（含自测） | 空壳 App 启动，深浅色令牌正确，迁移自测通过 |
| M2 此刻页 | Hero / 队列 / 三类精选 / 数据条 | 与概念稿视觉一致，双色正常 |
| M3 库页 + 详情 | 三个网格页、搜索筛选排序、沉浸详情、笔记条目 | 全链路浏览可用 |
| M4 收录流程 | 元数据搜索补全、EPUB 拖入、手动录入 | 收录闭环 |
| M5 统计 + 设置 | 统计页、外观说明、JSON 导入导出、存储管理 | 功能齐平 v2 |
| M6 收尾 | v2 旧代码与资源清理、迁移实测、版本 3.0.0、README 更新 | `./build.sh` 安装可用 |

每个里程碑完成后更新 `AGENTS.md` 的「仓库当前状态」一节。
