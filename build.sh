#!/bin/bash
set -e

echo "🎨 Building ArtShelf..."
cd "$(dirname "$0")/ArtShelf"

# Command Line Tools can briefly ship a compiler newer than the default SDK.
# The app targets macOS 14, so prefer the installed compatible SDK when present.
COMPATIBLE_SDK="/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk"
if [ -d "$COMPATIBLE_SDK" ]; then
    export SDKROOT="$COMPATIBLE_SDK"
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

# 复制新版 .icns（保留旧版资源作为回退）
if [ -f "ArtShelf-v2.icns" ]; then
    cp ArtShelf-v2.icns "$APP_DIR/Contents/Resources/ArtShelf.icns"
elif [ -f "ArtShelf.icns" ]; then
    cp ArtShelf.icns "$APP_DIR/Contents/Resources/ArtShelf.icns"
fi

# 复制稳定保存的应用清单
if [ -f "Resources/Info.plist" ]; then
    cp Resources/Info.plist "$APP_DIR/Contents/Info.plist"
fi

echo "📦 App bundle updated at: $(pwd)/$APP_DIR"
