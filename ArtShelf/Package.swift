// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ArtShelf",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "ArtShelf",
            path: "Sources/ArtShelf"
        )
    ]
)
