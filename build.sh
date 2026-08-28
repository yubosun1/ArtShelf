#!/bin/bash
set -e

echo "🎨 Building ArtShelf..."
cd "$(dirname "$0")/ArtShelf"

# 使用系统匹配的 SDK
if [ -z "$SDKROOT" ]; then
    export SDKROOT="$(xcrun --show-sdk-path)"
fi

# 编译 release
swift build -c release --disable-sandbox

echo "✅ Build complete."

# 更新 .app bundle 中的二进制
APP_DIR="ArtShelf.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# 复制二进制
cp .build/arm64-apple-macosx/release/ArtShelf "$APP_DIR/Contents/MacOS/ArtShelf"
chmod +x "$APP_DIR/Contents/MacOS/ArtShelf"

# 复制应用图标
if [ -f "ArtShelf.icns" ]; then
    cp ArtShelf.icns "$APP_DIR/Contents/Resources/ArtShelf.icns"
fi

# 复制多款应用图标资源（供动态切换）
if [ -d "Resources/Icons" ]; then
    cp -R "Resources/Icons" "$APP_DIR/Contents/Resources/"
fi

# 复制稳定保存的应用清单
if [ -f "Resources/Info.plist" ]; then
    cp Resources/Info.plist "$APP_DIR/Contents/Info.plist"
fi

echo "📦 App bundle updated at: $(pwd)/$APP_DIR"

if [ -d "/Applications/ArtShelf.app" ]; then
    rm -rf "/Applications/ArtShelf.app"
    cp -R "$APP_DIR" "/Applications/"
    echo "🚀 Also synchronized to /Applications/ArtShelf.app"
fi
