#!/bin/bash
set -e

# 打包 ArtShelf.app 为 DMG 安装镜像
# 用法：./Scripts/package_dmg.sh [版本号]   # 缺省取 Info.plist 的 CFBundleShortVersionString
# 产物：仓库根 ArtShelf-<版本>.dmg
cd "$(dirname "$0")/../.."
APP="ArtShelf/ArtShelf.app"

VERSION="${1:-$(defaults read "$(pwd)/$APP/Contents/Info" CFBundleShortVersionString)}"
DMG="ArtShelf-${VERSION}.dmg"

rm -f "$DMG"
hdiutil create -volname "ArtShelf" -srcfolder "$APP" -ov -format UDZO "$DMG" >/dev/null
echo "📦 已生成: $(pwd)/$DMG"
