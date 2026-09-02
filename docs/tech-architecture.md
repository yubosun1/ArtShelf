# ArtShelf 技术方案（v3）

> 配套文档：`docs/product-design.md`（产品设计，先读）

---

## 1. 技术栈

| 项 | 定案 | 说明 |
| :-- | :-- | :-- |
| 语言 / 工具链 | Swift 6.2，语言模式 Swift 6 | 严格并发检查 |
| UI 框架 | SwiftUI（按需下探 AppKit） | 窗口质感、系统外观跟随均为原生 |
| 数据持久层 | **JSON 文件存储**（Codable 值类型 + `@Observable` 仓库，防抖落盘） | 存储格式即导出线格式，与「数据透明」承诺一致 |
| 平台 / 部署目标 | macOS 14.0+，仅 macOS | |
| 工程形态 | Swift Package 单一 executable target | 一人项目万行量级，目录分层代替多模块拆分 |
| 第三方依赖 | **零**（纯系统框架） | 新增依赖需先讨论 |
| 测试 | 内置自测 `swift run ArtShelf --self-test`；离屏视觉对照 `--render-preview` | 本机仅有 Command Line Tools，无 XCTest；两者仅 Debug 构建包含 |
| 构建发布 | `build.sh` | 编译 release、打包 `.app`、同步 /Applications |

无跨平台需求，故不引入 Tauri / Electron / Flutter 等方案——概念稿的视觉效果 SwiftUI 均可原生实现。

## 2. 代码分层

单 target 内按目录强制分层，依赖方向自上而下，禁止反向引用：

```
Sources/ArtShelf/
├── main.swift               # 入口（--self-test / --render-preview 分支，仅 Debug）
├── ArtShelfApp.swift        # 窗口配置、菜单命令与快捷键
├── DesignSystem/            # 设计令牌（完整主题调色板）、封面加载与取色、光效组件、应用图标切换
├── Models/                  # Codable 值类型（MediaItem / NoteEntry / 枚举）
├── Services/                # 元数据抓取、EPUB 解析、文件与链接打开
├── Store/                   # LibraryStore 仓库、迁移器、导入导出、路径约定
├── SelfTest/                # 内置数据层自测、离屏预览渲染（仅 Debug）
└── Features/                # 按页面组织视图
    ├── Root/                # 外壳：顶栏、全局搜索、详情导航、Esc 分层
    ├── Now/                 # 「此刻」首页（Hero / 队列 / 精选 / 数据条）
    ├── Library/             # 片库 / 唱片 / 书架 网格页
    ├── Detail/              # 沉浸详情
    ├── Add/                 # 收录流程
    ├── Stats/               # 统计
    └── Settings/            # 设置
```

## 3. 数据层

> 持久层曾定为 SwiftData，因构建机仅有 Command Line Tools（宏插件缺失，`@Model` 无法编译）改回 JSON；千条以内量级下内存全量 + 防抖落盘性能绰绰有余。

### 3.1 模型与仓库

- `MediaItem`（Codable struct）：标题、创作者、年份、类型、简介、标签、评分、状态、封面（远程 URL + 本地缓存路径）、关联文件路径、`webURL`（在线观看链接，手动补）/ `referenceURL`（资料链接，搜索预填、只读查阅）、`appleMusicURL`、添加 / 最近浏览 / **最近品味时间 `lastTastedAt`**、**进度 `progressCurrent` / `progressTotal` / `progressUnit`**（影视可选分钟/集/期，书籍=页、音乐=音轨）、**重温次数 `replayCount`**、手记数组
- `NoteEntry`（Codable struct）：创建时间、正文
- `LibraryStore`（`@MainActor @Observable`）：内存全量持有 `items`（只读），修改经仓库方法执行并 **0.5s 防抖落盘**（退出时 flush）
- **解码容错**：未知枚举值落默认值（单条脏数据不拖垮整库）；v2 字段向下兼容（单条笔记字符串 → `[NoteEntry]`）

存储位置：`~/Library/Application Support/ArtShelf/library.json`（带 `schemaVersion: 3`），与 `covers/` 封面目录并列。

**状态流转副作用统一收口在 Store 层**（`startTasting` / `finish` / `replay` / `updateProgress` / `setTotal` / `markTasted`），视图不直接改状态字段；流转规则见 `product-design.md` §5。

### 3.2 JSON 导入导出

- `LibraryDocument`（Codable，带 `schemaVersion: 3`）**既是存储格式也是导出线格式**
- 设置面板提供「导出 JSON / 从 JSON 导入」（`Store/LibraryIO.swift`，NSSavePanel / NSOpenPanel）
- 导入校验版本头、按 id 去重（库内已有与文件内重复均跳过），进行中条目回填 `lastTastedAt`

### 3.3 迁移与一次性修正

首次启动检测 `library.json`：

1. v2 / v1 格式：备份原文件为 `library.v2.backup.json`（永不覆盖）→ 字段映射 + 新字段默认值（进度 0、`replayCount` 0、v2 单条笔记转手记、进行中藏品 `lastTastedAt` 回落到最近浏览时间）→ 立即落盘为 v3 格式；`covers/` 目录原样沿用
2. 文件损坏：备份为 `library.json.corrupt-<时间戳>` 并置 `loadFailed` 由 UI 提示，不碰原文件
3. **资料链接归位**：语义拆分前资料站链接误填在 `webURL`，加载时按域名边界匹配（douban / wikipedia / tvmaze / itunes / books.google）一次性搬回 `referenceURL`，有改动即落盘

迁移器由内置自测覆盖（构造样本 JSON 断言字段映射、默认值、备份与归位行为）。

## 4. 设计系统实现

- **语义令牌**：`DesignSystem/Theme.swift` 的 `Theme.bg` 等静态令牌全部转发到 `ThemeSettings` 单例的计算属性，依赖 Observation 运行时追踪，切换后全部引用点自动刷新；令牌口径与 `product-design.md` §4.1 一一对应，视图禁止硬编码色值
- **完整主题五套**：`DesignSystem/ThemeSettings.swift`（@Observable 单例，UserDefaults 键 `appTheme`）提供跟随系统 / 白昼放映厅 / 暗房 / 午夜蓝场 / 羊皮纸，每套给齐整套 `ThemePalette`（bg/titlebar/panel/ink×3/rule/well/track）；非「跟随系统」主题各自锁定浅 / 深 `NSApplication.appearance`，窗口 chrome 与 `colorScheme` 环境随之一致；旧 `appearanceMode` 键启动时一次性迁移
- **主题色四套**：琥珀 / 靛蓝 / 青玉 / 胭脂，与完整主题正交；`Theme.amber` 等令牌转发到 `ThemeSettings.shared.accent` 的计算属性
- **应用图标切换**：`DesignSystem/AppIcon.swift` 六款图标（v1 棱镜画架四色 + 暗房陈列 + 棱镜方块），设置内点选即 `NSApplication.applicationIconImage` 动态替换，UserDefaults（`appIcon`）持久化，启动时随 `applyAppearance()` 应用；生成脚本 `Scripts/generate_icons_v2.swift`（v1 四款为 `generate_icons.swift`）
- **封面主色光晕**：`NSImage+AverageColor.swift` 以 `CIAreaAverage` 降采样取主色，按令牌强度渲染
- **Hero 环境渲染**：封面图放大 + `.blur(radius:)` + 径向渐变叠色，底部渐隐融入画布
- **字体**：系统字体栈，不设自定义字体

## 5. 元数据来源（零 API Key）

| 类型 | 来源 |
| :-- | :-- |
| 影视 | **豆瓣 `subject_suggest`（主源，华语覆盖最好，标准海报 + 剧集集数）** → Wikipedia 摘要 + Wikidata 补导演/类型/日期 → iTunes → TVMaze（仅英文） |
| 音乐 | iTunes Search API（专辑封面、Apple Music 链接） |
| 书籍 | 豆瓣图书 + Google Books；本地 EPUB 解包提取内嵌封面 |

- 中文影视查询并发「电视剧」「电影」双关键词；多源结果按规范化标题**合并补缺**（豆瓣封面/年份/资料链接 → Wiki 简介与 Wikidata 字段 → 其余来源）
- 豆瓣海报 `s_ratio_poster`→`m_ratio_poster` 升中图、书封 `/s/`→`/l/` 升大图；`doubanio.com` 封面请求带 `Referer: https://www.douban.com/`（否则 418）
- 豆瓣 `episode` 字段带回总集数，剧集收录时自动按「集」建立进度
- 封面下载与内存缓存由 `DesignSystem/CoverImageView.swift` 内 `CoverImageLoader`（NSCache）承担，落盘 `covers/`

## 6. 窗口与交互

- SwiftUI `Window` 场景单窗口；隐藏工具栏标题，窗口 chrome 为单行 48pt（`WindowChrome`：styleMask 加 `fullSizeContentView` + titlebar 透明 + 忽略顶部安全区，红绿灯下移至顶栏视轴，缩放/激活时经通知重放偏移）
- 菜单命令：`.commands` 注册 `⌘1`–`⌘5` 切 Tab、`⌘N` 收录、`⌘F` 聚焦搜索
- 详情为整版页面（导航栈内切换）；`Esc` 分层关闭（搜索浮层 → 详情 → 收录）
- 全应用滚动条隐藏（滚动区与笔记输入框 `scrollIndicators(.hidden)`）
