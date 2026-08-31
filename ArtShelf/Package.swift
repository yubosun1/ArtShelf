// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ArtShelf",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "ArtShelf",
            path: "Sources/ArtShelf"
        )
        // 本机无完整 Xcode（无 XCTest），测试以内置自测替代：
        // swift run ArtShelf --self-test（见 Sources/ArtShelf/SelfTest/）
    ]
)
