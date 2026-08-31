# ArtShelf v3 技术方案

> 状态：已定稿（2026-08-31 讨论确认）
> 配套文档：`docs/product-design.md`（产品设计，先读）

---

## 1. 技术栈定案

| 项 | 定案 | 说明 |
| :-- | :-- | :-- |
| 语言 / 工具链 | Swift 6.2，语言模式 Swift 6 | 全新代码，从第一天开启严格并发检查 |
| UI 框架 | SwiftUI（按需下探 AppKit） | 窗口质感、毛玻璃、系统外观跟随均为原生 |
| 数据持久层 | **SwiftData** + JSON 导入导出 | `@Model` 声明式模型；JSON 导出维持数据透明承诺 |
| 平台 / 部署目标 | macOS 14.0+，仅 macOS | 不预留 iOS |
| 工程形态 | Swift Package 单一 executable target | 目录分层代替多模块拆分 |
| 第三方依赖 | **零**（纯系统框架） | 新增依赖需先讨论 |
| 测试 | XCTest（迁移器 / 服务解析 / 进度计算） | 首期不写 UI 测试 |
| 构建发布 | `build.sh`（保留沿用） | 版本号升至 3.0.0 |

### 为什么不用跨平台方案

Tauri / Electron / Flutter 在没有跨平台需求的前提下，只会牺牲原生质感（窗口、外观跟随、快捷键体系）换不到收益。概念稿中的所有视觉效果 SwiftUI 均可原生实现。

### 为什么不拆多模块 SPM

一人项目、万行级代码量，编译时间不是瓶颈。单 target + 严格目录分层足够，避免模块边界的维护税。

## 2. 代码分层

单 target 内按目录强制分层，依赖方向自上而下，禁止反向引用：

```
Sources/ArtShelf/
├── ArtShelfApp.swift        # 入口、窗口配置、菜单命令与快捷键
├── DesignSystem/            # 设计令牌（深浅双色）、光效组件、通用修饰符
├── Models/                  # SwiftData @Model、值类型、JSON DTO
├── Services/                # 元数据抓取、EPUB 解析、封面缓存、封面取色
├── Store/                   # ModelContainer 装配、查询封装、迁移器、导入导出
└── Features/                # 按页面组织视图
    ├── Now/                 # 「此刻」首页（Hero / 队列 / 精选 / 数据条）
    ├── Library/             # 片库 / 唱片 / 书架 网格页
    ├── Detail/              # 沉浸详情
    ├── Add/                 # 收录流程
    ├── Stats/               # 统计
    └── Settings/            # 设置
```

## 3. 数据层设计

### 3.1 SwiftData 模型

- `MediaItem`（@Model）：标题、创作者、年份、类型（影视/音乐/书籍）、简介、标签、评分、状态、封面文件名、关联文件路径、外部链接、添加时间、最近浏览时间、**最近品味时间 `lastTastedAt`**、**进度 `progressCurrent` / `progressTotal`（Int 对）**（影视=分钟、书籍=页、音乐=音轨，折算 0–1 展示）、**重温次数 `replayCount`**、笔记关系（一对多，级联删除）
- `NoteEntry`（@Model）：所属藏品、创建时间、正文。策展手记条目化，按时间倒序

存储位置：显式指定 `~/Library/Application Support/ArtShelf/library.store`，与既有 `covers/` 目录并列。

**状态流转副作用统一收口在 Store 层**（`startTasting` / `finish` / `replay` / `updateProgress` 方法），视图不直接改状态字段；流转规则见 `product-design.md` §6。

### 3.2 JSON 导入导出

- DTO 与 @Model 分离：`LibraryDocument`（Codable，带 `schemaVersion: 3`）作为导出线格式
- 设置面板提供「导出 JSON / 从 JSON 导入」；导出包含全部字段与笔记

### 3.3 v2 → v3 迁移

首次启动检测 `library.json`（v2 格式）存在且未迁移过：

1. 备份原文件为 `library.v2.backup.json`（永不覆盖）
2. 按字段映射解析并写入 SwiftData（新字段给默认值：`progressCurrent/Total = 0`，`replayCount = 0`，v2 单条笔记转为一条 `NoteEntry`）
3. `covers/` 封面目录原样沿用（文件名约定不变）
4. 写入迁移完成标记；任一步失败则保留原状并弹错提示，不碰用户数据

迁移器需有 XCTest 覆盖（构造 v2 样本 JSON → 断言字段映射与默认值）。

## 4. 设计系统实现

- **语义令牌**：`DesignSystem/Theme.swift` 以代码定义 `dynamic(light:dark:)` 颜色（沿用 v2 `ArtShelfStyle` 的 NSColor 动态色手法），令牌口径与 `product-design.md` §5.1 表格一一对应
- **外观跟随系统**：不手动管理主题，直接依赖系统外观；深浅两套令牌自动生效（v3 首期不提供手动切换）
- **封面主色光晕**：新增 `Services/CoverColorExtractor`——NSImage 降采样后取平均色/主色，按藏品缓存计算结果；视图用令牌中的 `ga/gs` 强度渲染
- **Hero 环境渲染**：封面图放大 + `.blur(radius:)` + 径向渐变叠色，浅色模式不透明度 0.5（令牌 `amb`）
- **字体**：系统字体栈，不设自定义字体

## 5. 既有服务迁移（逻辑原样搬运，接口现代化）

| v2 文件 | 处置 |
| :-- | :-- |
| `MetadataService.swift` | 保留多源抓取逻辑（Wikipedia/TVMaze/Apple/iTunes/Google Books），统一为 async/await，零 API Key 不变 |
| `EPUBService.swift` | 原样迁移 EPUB 解包取封面逻辑 |
| `ImageCache.swift` | 原样迁移（内存 + 磁盘双级缓存），接 SwiftData 的封面文件名约定 |
| `FileService.swift` / `LinkMetadataService.swift` | 原样迁移 |
| `ThemeManager.swift` | **废弃**，由 DesignSystem 令牌 + 系统外观取代 |
| `DataStore.swift` | **废弃**，由 SwiftData 装配层取代 |
| 三个拟物封面视图（`MovieCoverView` / `MusicCoverView` / `BookCoverView`） | **废弃**，v3 为平铺封面 + 光效 |

## 6. 窗口与交互

- SwiftUI `Window` 场景单窗口；隐藏工具栏标题，顶栏自绘（Tab / 搜索 / 收录按钮）
- 菜单命令：`.commands` 注册 `⌘1`–`⌘5` 切 Tab、`⌘N` 收录、`⌘F` 聚焦搜索、`Esc` 关弹层
- 详情由 v2 的弹窗改为整版页面（导航栈内切换），`Esc` 返回

## 7. 里程碑

| 里程碑 | 内容 | 验收 |
| :-- | :-- | :-- |
| M1 骨架 | 工程清理、Swift 6 模式、DesignSystem 令牌、SwiftData 模型与装配、v2→v3 迁移器（含测试） | 空壳 App 启动，深浅色令牌正确，迁移测试通过 |
| M2 此刻页 | Hero / 队列 / 三类精选 / 数据条 | 与概念稿视觉一致，双色正常 |
| M3 库页 + 详情 | 三个网格页、搜索筛选排序、沉浸详情、笔记条目 | 全链路浏览可用 |
| M4 收录流程 | 元数据搜索补全、EPUB 拖入、手动录入 | 收录闭环 |
| M5 统计 + 设置 | 统计页、外观说明、JSON 导入导出、存储管理 | 功能齐平 v2 |
| M6 收尾 | v2 旧代码与资源清理、迁移实测、版本 3.0.0、README 更新 | `./build.sh` 安装可用 |

每个里程碑完成后更新 `AGENTS.md` 的「仓库当前状态」一节。
