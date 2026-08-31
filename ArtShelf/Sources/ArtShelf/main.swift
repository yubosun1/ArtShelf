// main.swift —— 应用入口
import SwiftUI

#if DEBUG
// 自测模式：`swift run ArtShelf --self-test`（仅 Debug 构建可用）
if CommandLine.arguments.contains("--self-test") {
    exit(SelfTest.run())
}
// 离屏渲染预览：`swift run ArtShelf --render-preview <输出目录>`（仅 Debug 构建可用）
if let idx = CommandLine.arguments.firstIndex(of: "--render-preview"),
   CommandLine.arguments.indices.contains(idx + 1) {
    exit(PreviewRenderer.run(outputDir: CommandLine.arguments[idx + 1]))
}
#endif

ArtShelfApp.main()
