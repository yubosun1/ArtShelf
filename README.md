# ArtShelf

<p align="center">
  <img src="ArtShelf/Resources/Icons/prism_ivory.png" alt="ArtShelf Icon" width="128" height="128" style="border-radius: 28px; box-shadow: 0 12px 28px rgba(0,0,0,0.18);">
</p>

<p align="center">
  <strong>一个为 macOS 精心打造的原生个人审美与全品类媒体策展空间</strong><br>
  电影胶片的光影、黑胶唱片的律动、案头书卷的墨香——把你的整个精神世界，安置在一个温润雅致的书架上。
</p>

<p align="center">
  <img src="https://img.shields.io/badge/version-2.0.0-blue" alt="Version 2.0.0">
  <img src="https://img.shields.io/badge/macOS-14.0%2B%20Sonoma%20%7C%20Sequoia-333333?logo=apple" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Swift-5.9%20%7C%20SwiftUI%20Native-FA7343?logo=swift" alt="Swift 5.9">
  <img src="https://img.shields.io/badge/Architecture-Apple%20Silicon%20%7C%20Intel-blue" alt="Architecture">
  <img src="https://img.shields.io/badge/License-MIT-green" alt="MIT License">
  <img src="https://img.shields.io/badge/Privacy-100%25%20Local%20First-success" alt="Local First">
</p>

---

## 📸 界面预览

<p align="center">
  <img src="docs/screenshots/main.png" alt="ArtShelf 主界面" width="100%" style="border-radius: 12px; box-shadow: 0 16px 40px rgba(0,0,0,0.16);">
</p>

---

## ✨ 核心特性

### 🏛️ 现代画廊主页 (Artisan Atelier Home)
- **艺术策展数据矩阵**：直观汇总影视、音乐、书籍的收藏总量，在看、在听、在读的实时品味进度一目了然。
- **正在品味 (In Progress) 焦点条**：将当前正在阅读或观赏的藏品置于视觉中心，随时继续体验。
- **三大专属媒体陈列架**：
  - **影视精选 (2:3)**：大画幅电影海报微距缩放与状态标识；
  - **黑胶唱片 (1:1)**：方正黑胶封面比例与光盘微纹理质感；
  - **案头藏书 (2:3)**：典雅精装书衣设计与优雅书卷排版；
  - 每条分类展架均支持水平流畅滑动，并附带“查看全部 ›”一键直达分类书架。

### 🎨 东方意蕴与现代排版美学
- **现代编辑美学**：宋体标题 + 象牙纸底（Ivory Paper）+ 发丝细线，克莱因靛蓝（Klein Indigo）艺术强调色与朱砂红印点睛。
- **微浮雕光感**：柔和环境微光（Ambient Light）、微悬浮动效反馈、原生毛玻璃与精雕倒角。
- **极致无干扰**：全面消解原生滚动条与槽位，还原沉浸纯净的书房观赏体验。

### ⚙️ 自由定制：深浅模式与动态图标切换
- **全局深浅外观随心切换**：
  - `跟随系统`：无缝自适应 macOS 全局外观；
  - `浅色模式`：温润素雅的象牙纸白画廊风格；
  - `深色模式`：沉浸深邃的深空炭灰暗房风格。
- **4 款官方定制棱镜图标，程序坞 (Dock) 实时动态切换**：
  基于「棱镜之架与灵感光谱 (The Prism Easel)」设计理念，支持在设置面板中直接点击更换，即刻生效：
  - ⚪ **象牙画廊纯白**（默认推荐）：纯净画廊底色，水晶棱镜折射全彩光谱；
  - 🔵 **晴空微晶淡蓝**：清晨微风晴空浅蓝，清爽灵动呼吸感；
  - 🌸 **珍珠粉晕暖白**：柔美珍珠粉金微晕，与温柔浪漫、治愈生活心动呼应；
  - ⚫ **深空暮夜棱镜**：经典黑曜石深邃背景，沉稳克制极客范。

### 🔍 智能元数据与多源合流补全
- 输入标题或关键词，自动检索补全封面海报、导演/作者、发行年份、内容简介与分类：
  - 🎬 **影视**：Wikipedia 高清海报 + TVMaze + Apple 剧集目录
  - 🎵 **音乐**：iTunes Search API（高保真专辑封面）
  - 📖 **书籍**：Google Books API
- **零配置开箱即用**：全部基于公开免费接口，**无需配置任何 API Key**。

### 📖 本地 EPUB 封面精准提取
- 支持直接拖入或导入本地 `.epub` 电子书文件：
  - 自动解包解析，采用 `cover-image` 属性定位、`meta name="cover"` 解析及语义启发式查找多重策略；
  - 秒级提取原汁原味的高清内嵌封面图，无需手动寻找海报。

### 🗂️ 深度记录与关联交互
- **评分与鉴赏笔记**：0–5 星自由打分、专属心情感想短评、自定义多标签（Tags）分类归档。
- **文件与在线链接关联**：每条藏品可关联本地影音/书籍文件或外部网页链接，双击一键唤起系统默认应用打开。
- **多维度检索与排序**：支持全字段秒级搜索，以及按智能权重、最近浏览、添加时间、标题与评分排序。

---

## 🔒 数据安全与隐私承诺

- **100% 本地优先 (Local First)**：所有收藏记录以规范 JSON 保存在本地 `~/Library/Application Support/ArtShelf/library.json`。
- **本地封面存储**：所有媒体封面图片缓存于 `~/Library/Application Support/ArtShelf/covers/`。
- **零云端、无遥测**：不收集任何用户行为，不上传任何个人数据，无任何远程分析 SDK。
- **真正私有**：代码仓库与发行版本中绝不包含任何用户的本地收藏数据与个人笔记。

---

## ⌨️ 常用快捷键

| 快捷键 | 功能操作 |
| :--- | :--- |
| `⌘ ,` | 打开**偏好设置**（外观模式、应用图标切换、存储管理） |
| `⌘ N` | **添加新媒体**（快速搜索元数据或手动收录） |
| `⌘ F` | 快速聚焦**全局搜索框** |
| `Esc` | 关闭当前弹窗 / 详情面板 |

---

## 🚀 编译与构建

### 系统要求
- macOS 14.0 (Sonoma) 或更高版本
- 安装有 Xcode 命令行工具或完整 Xcode

### 一键构建与安装
ArtShelf 提供了便捷的顶层自动化脚本，编译 release 二进制、打包完整 `.app` 资源并自动同步至系统应用目录：

```bash
# 克隆仓库
git clone https://github.com/yubosun1/ArtShelf.git
cd ArtShelf

# 一键编译并打包安装到 /Applications
./build.sh
```

构建完成后，你可以在系统的「启动台 (Launchpad)」或 `/Applications/ArtShelf.app` 中直接启动使用。

---

## 📁 项目目录结构

```
ArtShelf/
├── build.sh                          # 自动化构建、资源打包与系统安装脚本
├── README.md                         # 项目设计与使用文档
├── LICENSE                           # MIT 开源许可证
├── docs/                             # 文档与预览截图
│   └── screenshots/main.png          # 官方主界面截图
└── ArtShelf/
    ├── Package.swift                  # Swift Package 清单（macOS 14+）
    ├── ArtShelf.icns                 # 打包生成的 macOS 主应用图标
    ├── Resources/                    # 资源目录
    │   ├── Info.plist                # 应用权限与环境配置清单
    │   ├── icon.png                  # 默认高分辨率图标源
    │   └── Icons/                    # 4 款可动态切换的高清棱镜系列图标
    ├── Scripts/
    │   ├── generate_icons.swift      # 官方矢量图标渲染生成脚本 (Swift + CoreGraphics)
    │   └── package_icon.sh           # 将源图打包转换为 .icns 工具脚本
    └── Sources/ArtShelf/
        ├── ArtShelfApp.swift         # 应用程序入口、主菜单命令与快捷键体系
        ├── Models/                   # 核心数据模型 (MediaItem / MediaType / MediaStatus)
        ├── Services/                 # 元数据自动抓取、EPUB 封面解压、本地文件服务
        ├── Store/                    # 数据持久化 (DataStore) 与主题外观管理 (ThemeManager)
        └── Views/                    # 纯原生 SwiftUI 视图层
            ├── HomeView.swift        # 艺术画廊主页与数据矩阵
            ├── BookshelfView.swift   # 分类书架陈列与流式瀑布流
            ├── SettingsView.swift    # 偏好设置面板（外观与图标动态切换）
            ├── DetailView.swift      # 媒体全功能沉浸详情弹窗
            ├── AddMediaView.swift    # 媒体收录与元数据补全弹窗
            ├── SidebarView.swift     # 侧边栏导航与设置入口
            └── ArtShelfStyle.swift   # 现代画廊设计系统与调色板规范
```

---

## 📜 开源许可证

本项目基于 [MIT License](LICENSE) 协议开源。
