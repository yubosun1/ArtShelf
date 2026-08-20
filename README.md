# ArtShelf

一个 macOS 原生媒体收藏管理应用，用 SwiftUI 编写。用来管理你看过的电影、在听的专辑、想读的书——把整个媒体库放进一个温暖的书架上。

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-333333?logo=apple)
![Swift](https://img.shields.io/badge/Swift-5.9-FA7343?logo=swift)
![License](https://img.shields.io/badge/License-MIT-green)

## 功能特性

- 📚 **三种媒体类型**：影视、音乐、书籍，各有专属的封面比例与状态文案（待看/在看/已看、待听/在听/已听、待读/在读/已读）
- 🎨 **书房画廊风格**：宋体标题 + 象牙纸底 + 发丝线分隔的编辑排版，朱砂红一点如印章；状态用琥珀/橄榄/石灰三色点安静区分
- 🔍 **元数据自动补全**：搜索时从多个公开 API 拉取标题、作者/导演、年份、简介、高清封面
  - 影视：Wikipedia（含海报）+ TVMaze + Apple 剧集目录
  - 音乐：iTunes Search API
  - 书籍：Google Books API
- 🖼️ **封面管理**：远程封面自动缓存到本地，也可手动选择本地图片
- 📖 **EPUB 封面提取**：自动解压 EPUB 并提取封面图（多种策略：`cover-image` 属性、`meta name="cover"`、启发式）
- ⭐ **评分与笔记**：0–5 星评分、个人感想、标签分类
- 📁 **文件关联**：每条记录可关联本地文件或在线链接，一键用系统默认应用打开
- 💾 **本地优先存储**：所有数据以 JSON 保存在 `~/Library/Application Support/ArtShelf/library.json`，无云端依赖
- ⌨️ **快捷键**：`⌘N` 添加媒体，`⌘F` 搜索

## 截图

![ArtShelf 主界面](docs/screenshots/main.png)

## 系统要求

- macOS 14.0 (Sonoma) 或更高
- Apple Silicon 或 Intel

## 数据与隐私

- 所有数据保存在本地 `~/Library/Application Support/ArtShelf/`
- 封面图片缓存于 `~/Library/Application Support/ArtShelf/covers/`
- 元数据搜索仅在你主动添加媒体时，向对应公开 API 发起请求
- **无需任何 API 密钥**，全部使用公开的免费接口

## 目录结构

```
ArtShelf/
├── build.sh                          # 顶层构建脚本
└── ArtShelf/
    ├── Package.swift                  # Swift Package 定义（macOS 14+）
    ├── Sources/ArtShelf/
    │   ├── ArtShelfApp.swift         # App 入口与快捷键
    │   ├── Models/                   # 数据模型（MediaItem/Type/Status）
    │   ├── Views/                    # SwiftUI 视图（书架/详情/添加/侧栏…）
    │   ├── Services/                 # 元数据搜索、EPUB 封面、文件服务
    │   └── Store/                    # 数据存储与全局状态
    ├── Resources/                    # Info.plist 与图标源文件
    ├── Scripts/                      # 图标生成脚本
    └── ArtShelf.icns                 # 应用图标
```

## 许可证

[MIT](LICENSE)
