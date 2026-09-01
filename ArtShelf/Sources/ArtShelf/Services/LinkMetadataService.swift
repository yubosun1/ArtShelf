import Foundation
import os

/// 从网页链接提取的元数据（OpenGraph 标准）
struct LinkMetadata: Sendable {
    let title: String?
    let coverURL: String?
    let description: String?
}

/// 链接元数据服务——手动添加时，从用户粘贴的网页链接里
/// 抓取 OpenGraph 元数据（og:title / og:image / og:description），
/// 自动补全标题、封面与简介。
///
/// 兼容常见的页面（豆瓣、IMDb、TMDB、维基、YouTube、Apple 等），
/// 这些站点大多输出 og: 标签。抓取失败时返回 nil，由调用方回退到纯手动填写。
final class LinkMetadataService: Sendable {

    static let shared = LinkMetadataService()

    /// 日志（subsystem 统一为 "ArtShelf"，category 为类名）
    private static let logger = Logger(subsystem: "ArtShelf", category: "LinkMetadataService")

    private init() {}

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15"
        ]
        return URLSession(configuration: config)
    }()

    /// 从链接抓取元数据（异步）
    func fetch(from urlString: String) async -> LinkMetadata? {
        guard let url = URL(string: urlString),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host != nil else {
            return nil
        }

        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else {
                return nil
            }

            // 按 UTF-8 解析，失败再尝试 Latin-1（部分站点不规范）
            let html = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .isoLatin1)
            guard let html else { return nil }

            return parse(html: html, baseURL: url)
        } catch {
            Self.logger.error("链接元数据抓取失败: \(error, privacy: .public)")
            return nil
        }
    }

    // MARK: - 解析

    private func parse(html: String, baseURL: URL) -> LinkMetadata {
        let title = ogValue(property: "og:title", in: html)
            ?? htmlTitle(in: html)
        let cover = ogValue(property: "og:image", in: html)
        let description = ogValue(property: "og:description", in: html)
            ?? ogValue(property: "description", in: html)

        return LinkMetadata(
            title: title?.htmlDecoded.trimmingCharacters(in: .whitespacesAndNewlines),
            coverURL: cover.map { resolveAbsoluteURL($0, base: baseURL) },
            description: description?.htmlDecoded.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    /// 提取 `<meta property="og:xxx" content="...">` 或
    /// `<meta name="og:xxx" content="...">` 的 content 值
    private func ogValue(property: String, in html: String) -> String? {
        // 两种常见写法：property= 与 name=；属性值兼容双引号 / 单引号
        for attr in ["property", "name"] {
            for quote in ["\"", "'"] {
                // <meta ... property="og:title" ...> —— 属性可能在 content 前后
                if let value = metaContent(attr: attr, attrValue: property, quote: quote, in: html) {
                    return value
                }
            }
        }
        return nil
    }

    /// 在 `<meta ...>` 标签中，先定位 attr=quote+attrValue+quote，再取出同一标签内 content="..."
    private func metaContent(attr: String, attrValue: String, quote: String, in html: String) -> String? {
        let pattern = "\(attr)=\(quote)\(attrValue)\(quote)"

        var searchRange = html.startIndex..<html.endIndex
        while let matchRange = html.range(of: pattern, options: .caseInsensitive, range: searchRange) {
            // 向后找最近的 <meta 标签起点
            let prefix = String(html[html.startIndex..<matchRange.lowerBound])
            guard let metaStart = prefix.range(of: "<meta", options: [.backwards, .caseInsensitive])?.lowerBound else {
                return nil
            }
            // 找到该标签的结束点（下一个 > 或 />）
            let tagEndRange = html.range(
                of: ">",
                options: .caseInsensitive,
                range: metaStart..<html.endIndex
            )
            guard let tagEnd = tagEndRange?.lowerBound else { return nil }
            let tag = String(html[metaStart..<tagEnd])

            // 在标签内找 content="..."
            if let content = extractContent(from: tag) {
                return content
            }
            searchRange = tagEnd..<html.endIndex
        }
        return nil
    }

    /// 从一个 meta 标签文本中提取 content="..." 的值（兼容单引号与无引号）
    private func extractContent(from tag: String) -> String? {
        // content="..."
        if let range = tag.range(of: "content=\"", options: .caseInsensitive) {
            let start = range.upperBound
            if let end = tag[start...].firstIndex(of: "\"") {
                return String(tag[start..<end])
            }
        }
        // content='...'
        if let range = tag.range(of: "content='", options: .caseInsensitive) {
            let start = range.upperBound
            if let end = tag[start...].firstIndex(of: "'") {
                return String(tag[start..<end])
            }
        }
        // content=... 无引号（到空白或 > 为止）
        if let range = tag.range(of: "content=", options: .caseInsensitive) {
            let start = range.upperBound
            let remainder = tag[start...]
            let end = remainder.firstIndex { $0 == " " || $0 == ">" || $0 == "/" } ?? remainder.endIndex
            let value = String(remainder[..<end]).trimmingCharacters(in: .whitespaces)
            if !value.isEmpty && value != "/" {
                return value
            }
        }
        return nil
    }

    /// 回退：取 <title>...</title>
    private func htmlTitle(in html: String) -> String? {
        guard let open = html.range(of: "<title", options: .caseInsensitive),
              let closeOpen = html.range(of: ">", range: open.upperBound..<html.endIndex)?.lowerBound,
              let close = html.range(of: "</title>", options: .caseInsensitive, range: closeOpen..<html.endIndex)?.lowerBound else {
            return nil
        }
        return String(html[closeOpen..<close])
    }

    /// 将相对路径 / 协议相对路径解析为绝对 URL
    private func resolveAbsoluteURL(_ raw: String, base: URL) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed) else { return trimmed }

        if url.scheme != nil {
            // 已是完整 URL，但若是 //host/path 协议相对，补上 https:
            if trimmed.hasPrefix("//") {
                return "https:\(trimmed)"
            }
            return trimmed
        }
        // 相对路径 → 用 base 拼接
        if let absolute = URL(string: trimmed, relativeTo: base)?.absoluteString {
            return absolute
        }
        return trimmed
    }
}

// MARK: - HTML 实体解码

private extension String {
    /// 简单解码常见 HTML 实体（手写解析，避免正则表达式在后台线程抛 Obj-C 异常）
    var htmlDecoded: String {
        var result = self
        let entities: [String: String] = [
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&#39;": "'",
            "&#039;": "'",
            "&nbsp;": " ",
            "&ndash;": "–",
            "&mdash;": "—",
            "&hellip;": "…"
        ]
        for (entity, value) in entities {
            result = result.replacingOccurrences(of: entity, with: value)
        }
        // 数字实体 &#NNN; —— 手写扫描
        if result.contains("&#") {
            result = result.decodingNumericEntities
        }
        return result
    }

    /// 将 `&#123;` 形式的数字实体替换为对应字符
    private var decodingNumericEntities: String {
        var output = ""
        var i = startIndex
        while i < endIndex {
            if self[i] == "&",
               let hashIdx = index(i, offsetBy: 1, limitedBy: endIndex), self[hashIdx] == "#" {
                // 从 i+2 开始收集数字
                var cursor = index(hashIdx, offsetBy: 1, limitedBy: endIndex) ?? endIndex
                var digits = ""
                while cursor < endIndex {
                    let ch = self[cursor]
                    if ch.isNumber {
                        digits.append(ch)
                        cursor = index(after: cursor)
                    } else if ch == ";" {
                        if let code = Int(digits), let scalar = UnicodeScalar(code) {
                            output.append(Character(scalar))
                        } else {
                            output.append("&#\(digits);")
                        }
                        i = index(after: cursor)
                        break
                    } else {
                        // 不是合法的数字实体，保留原文
                        output.append("&#\(digits)")
                        i = cursor
                        break
                    }
                }
                if cursor >= endIndex {
                    output.append("&#\(digits)")
                    i = endIndex
                }
            } else {
                output.append(self[i])
                i = index(after: i)
            }
        }
        return output
    }
}
