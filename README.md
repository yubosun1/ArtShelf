# ArtShelf

一个为 macOS 精心打造的原生个人媒体与审美收藏管理应用，采用 SwiftUI 纯原生编写。用来管理你看过的电影、在听的专辑、想读的书，并面向未来扩展女团与偶像追星小卡、写真周边、精选壁纸等全品类热爱——把你的整个精神世界放进一个温暖的书架上。

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-333333?logo=apple)
![Swift](https://img.shields.io/badge/Swift-5.9-FA7343?logo=swift)
![License](https://img.shields.io/badge/License-MIT-green)

## 功能特性

- 📚 **多媒体与全品类审美策展**：影视、音乐、书籍全覆盖，各有专属的封面比例与状态文案（待看/在看/已看、待听/在听/已听、待读/在读/已读）；未来架构更将无缝支持女团追星、小卡周边、精选壁纸画幅等。
- 🎨 **现代书房画廊风格**：宋体标题 + 象牙纸底 + 发丝线分隔的编辑排版，朱砂红一点如印章；状态用琥珀/橄榄/石灰三色点安静区分。
- 🌓 **深浅外观随心切换**：支持「跟随系统」、「浅色模式（纯净象牙白）」与「深色模式（沉浸式深空炭灰）」一键切换，即时生效。
- 💎 **应用图标动态定制**：基于「棱镜之架与灵感光谱 (The Prism Easel)」设计理念，内置 4 款精心调校的高清应用图标（象牙画廊纯白、晴空微晶淡蓝、珍珠粉晕暖白、深空暮夜棱镜），支持在设置中一键实时切换 macOS 程序坞 (Dock) 图标。
- 🔍 **元数据自动补全**：搜索时从多个公开 API 自动拉取标题、作者/导演、年份、简介、高清封面：
  - 影视：Wikipedia（含海报）+ TVMaze + Apple 剧集目录
  - 音乐：iTunes Search API
  - 书籍：Google Books API
- 🖼️ **封面管理**：远程封面自动缓存到本地，也可手动选择本地图片替换。
- 📖 **EPUB 封面提取**：自动解压本地 EPUB 文件并提取高精度封面图（支持 `cover-image` 属性、`meta name="cover"` 及启发式提取策略）。
- ⭐ **评分与笔记**：0–5 星评分、个人感想与深度短评、标签自由分类。
- 📁 **文件与链接关联**：每条记录可关联本地文件或网络链接，一键唤起系统默认应用打开。
- 💾 **本地优先，绝对隐私**：所有用户数据与封面严格保存在本地，无任何云端上传与追踪，真正属于你的数字策展馆。
- ⌨️ **原生快捷键**：`⌘,` 打开偏好设置，`⌘N` 添加媒体，`⌘F` 聚焦搜索。

## 截图

![ArtShelf 主界面](docs/screenshots/main.png)

## 系统要求

- macOS 14.0 (Sonoma) 或更高版本
- Apple Silicon 或 Intel 架构处理器

## 数据与隐私保护

- 所有数据完全保存在本地 `~/Library/Application Support/ArtShelf/`
- 封面图片缓存于 `~/Library/Application Support/ArtShelf/covers/`
- 元数据搜索仅在你主动添加媒体时向对应公开 API 发起请求
- **无需任何 API 密钥**，全部使用公开的免费接口
- 代码仓库与 Git 提交不会包含任何本地个人收藏内容与隐私数据

## 目录结构

```
ArtShelf/
├── build.sh                          # 顶层一键构建与安装脚本
└── ArtShelf/
    ├── Package.swift                  # Swift Package 定义（macOS 14+）
    ├── Sources/ArtShelf/
    │   ├── ArtShelfApp.swift         # App 入口、菜单命令与快捷键
    │   ├── Models/                   # 数据模型（MediaItem/Type/Status）
    │   ├── Views/                    # SwiftUI 视图（主页/书架/详情/添加/设置/侧栏…）
    │   │   ├── SettingsView.swift    # 偏好设置面板（外观模式与应用图标切换）
    │   │   └── ...
    │   ├── Services/                 # 元数据搜索、EPUB 封面提取、文件关联
    │   └── Store/                    # 数据存储、ThemeManager 主题管理与全局状态
    ├── Resources/                    # Info.plist、默认主图标及多款可切换图标
    │   ├── Icons/                    # 4 款高清棱镜系列图标资源
    │   └── ...
    ├── Scripts/                      # 官方矢量图标生成脚本 (generate_icons.swift)
    └── ArtShelf.icns                 # 打包生成的默认应用图标
```

## 许可证

[MIT](LICENSE)
