// main.swift —— 应用入口
import SwiftUI

#if DEBUG
// 自测模式：`swift run ArtShelf --self-test`（仅 Debug 构建可用）
if CommandLine.arguments.contains("--self-test") {
    exit(SelfTest.run())
}
#endif

ArtShelfApp.main()
