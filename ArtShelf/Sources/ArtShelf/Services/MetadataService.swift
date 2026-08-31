import Foundation
import os

/// 搜索结果统一模型
struct SearchResult: Identifiable {
    let id = UUID()
    let title: String
    let creator: String?
    let year: Int?
    let genre: String?       // 流派 / 类型（如 Drama · Thriller）
    let coverURL: String?
    let synopsis: String?
    let webURL: String?
    let type: MediaType
    let albumName: String?
    let appleMusicURL: String?
}

// MARK: - iTunes Search API 响应

private struct ITunesResponse: Codable {
    let resultCount: Int
    let results: [ITunesResult]
}

private struct ITunesResult: Codable {
    let trackName: String?
    let collectionName: String?
    let artistName: String?
    let artworkUrl100: String?
    let longDescription: String?
    let shortDescription: String?
    let trackViewUrl: String?
    let collectionViewUrl: String?
    let releaseDate: String?
    let primaryGenreName: String?

    /// 获取高清封面 URL（替换为 600x600）
    var highResArtwork: String? {
        guard let art = artworkUrl100 else { return nil }
        return art
            .replacingOccurrences(of: "100x100bb", with: "600x600bb")
            .replacingOccurrences(of: "100x100", with: "600x600")
    }
}

// MARK: - Google Books API 响应

private struct GoogleBooksResponse: Codable {
    let totalItems: Int
    let items: [GoogleBookItem]?
}

private struct GoogleBookItem: Codable {
    let id: String
    let volumeInfo: VolumeInfo
}

private struct VolumeInfo: Codable {
    let title: String?
    let authors: [String]?
    let description: String?
    let imageLinks: ImageLinks?
    let publishedDate: String?
    let previewLink: String?
    let infoLink: String?
}

private struct ImageLinks: Codable {
    let smallThumbnail: String?
    let thumbnail: String?
}

// MARK: - Wikipedia API 响应

private struct WikipediaResponse: Decodable {
    let query: WikipediaQuery?
}

private struct WikipediaQuery: Decodable {
    let pages: [String: WikipediaPage]
}

private struct WikipediaPage: Decodable {
    let pageid: Int
    let title: String
    let index: Int?
    let thumbnail: WikipediaThumbnail?
    let extract: String?
    let fullurl: String?
}

private struct WikipediaThumbnail: Decodable {
    let source: String
}

/// REST `page/summary` 的响应。
///
/// 这个端点会返回条目的首图，**包括合理使用的非自由图片**——
/// 而 action API 的 `prop=pageimages` 只给自由许可的图，
/// 因此电影海报在那里永远是 nil。海报只能从这里拿。
private struct WikipediaSummary: Decodable {
    let thumbnail: WikipediaThumbnail?
    let originalimage: WikipediaThumbnail?
}

// MARK: - TVMaze API 响应

private struct TVMazeSearchResult: Decodable {
    let show: TVMazeShow
}

private struct TVMazeShow: Decodable {
    let name: String
    let genres: [String]
    let premiered: String?
    let image: TVMazeImage?
    let summary: String?
    let url: String?
}

private struct TVMazeImage: Decodable {
    let medium: String?
    let original: String?
}

/// 元数据搜索服务
final class MetadataService {

    static let shared = MetadataService()
    private init() {}

    private let logger = Logger(subsystem: "ArtShelf", category: "MetadataService")

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        return URLSession(configuration: config)
    }()

    // MARK: - 统一搜索入口

    func search(query: String, type: MediaType) async -> [SearchResult] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        switch type {
        case .movie: return await searchMoviesAndTV(query: query)
        case .music: return await searchMusic(query: query)
        case .book:  return await searchBooks(query: query)
        }
    }

    // MARK: - 影视搜索（电影 + 电视剧，合并结果）

    /// 电影走 Wikipedia（含海报），剧集走 TVMaze 与 Apple 的剧集目录。
    ///
    /// 注意：iTunes 的 `media=movie` 已经下线，任何关键词都返回 0 条，
    /// 所以这里不再请求它——电影海报改由 Wikipedia REST 的首图提供。
    private func searchMoviesAndTV(query: String) async -> [SearchResult] {
        async let movies = searchWikipediaMovies(query: query)
        async let tvMazeShows = searchTVMaze(query: query)
        async let appleTVShows = searchITunes(
            query: query,
            media: "tvShow",
            entity: "tvSeason",
            country: "us"
        )

        let combined = await (movies + tvMazeShows + appleTVShows).deduplicated()

        // 有海报的排前面——带图的条目更容易辨认。
        // 手写分组而不用 sorted(by:)：后者不保证稳定，会打乱各组内的相关度顺序。
        let withCover = combined.filter { $0.coverURL != nil }
        let withoutCover = combined.filter { $0.coverURL == nil }
        return Array((withCover + withoutCover).prefix(30))
    }

    // MARK: - 音乐搜索（专辑）

    private func searchMusic(query: String) async -> [SearchResult] {
        await searchITunes(query: query, media: "music", entity: "album")
    }

    // MARK: - iTunes 通用搜索

    private func searchITunes(
        query: String,
        media: String,
        entity: String? = nil,
        country: String = "cn"
    ) async -> [SearchResult] {
        var components = URLComponents(string: "https://itunes.apple.com/search")
        components?.queryItems = [
            URLQueryItem(name: "term", value: query),
            URLQueryItem(name: "media", value: media),
            URLQueryItem(name: "country", value: country),
            URLQueryItem(name: "limit", value: "20")
        ]
        if let entity {
            components?.queryItems?.append(URLQueryItem(name: "entity", value: entity))
        }
        guard let url = components?.url else { return [] }

        do {
            let resp: ITunesResponse = try await fetch(url)
            return resp.results.compactMap { result in
                let title = result.trackName ?? result.collectionName ?? "未知"
                guard !title.isEmpty else { return nil }
                let isMusic = media == "music"
                return SearchResult(
                    title: isMusic ? (result.collectionName ?? title) : title,
                    creator: result.artistName,
                    year: extractYear(from: result.releaseDate),
                    genre: result.primaryGenreName,
                    coverURL: result.highResArtwork,
                    synopsis: result.longDescription ?? result.shortDescription,
                    webURL: result.trackViewUrl ?? result.collectionViewUrl,
                    type: isMusic ? .music : .movie,
                    albumName: isMusic ? result.collectionName : nil,
                    appleMusicURL: isMusic ? result.collectionViewUrl : nil
                )
            }
        } catch {
            logger.warning("iTunes 搜索失败 [\(media, privacy: .public)]: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    // MARK: - 电影搜索（Wikipedia，无需 API 密钥）

    private func searchWikipediaMovies(query: String) async -> [SearchResult] {
        let language = query.containsCJK ? "zh" : "en"
        let movieKeyword = language == "zh" ? "电影" : "film"
        var components = URLComponents(string: "https://\(language).wikipedia.org/w/api.php")
        components?.queryItems = [
            URLQueryItem(name: "action", value: "query"),
            URLQueryItem(name: "generator", value: "search"),
            URLQueryItem(name: "gsrsearch", value: "\(query) \(movieKeyword)"),
            URLQueryItem(name: "gsrnamespace", value: "0"),
            URLQueryItem(name: "gsrlimit", value: "12"),
            URLQueryItem(name: "prop", value: "pageimages|extracts|info"),
            URLQueryItem(name: "piprop", value: "thumbnail"),
            URLQueryItem(name: "pithumbsize", value: "600"),
            URLQueryItem(name: "exintro", value: "1"),
            URLQueryItem(name: "explaintext", value: "1"),
            URLQueryItem(name: "exsentences", value: "3"),
            URLQueryItem(name: "inprop", value: "url"),
            URLQueryItem(name: "format", value: "json")
        ]
        guard let url = components?.url else { return [] }

        do {
            let response: WikipediaResponse = try await fetch(url)
            let needle = query.lowercased()
            let pages = response.query?.pages.values.sorted {
                ($0.index ?? .max) < ($1.index ?? .max)
            } ?? []

            let candidates = pages
                .filter { page in
                    let title = page.title.lowercased()
                    let extract = page.extract?.lowercased() ?? ""
                    return title.contains(needle)
                        || needle.contains(title)
                        || extract.contains(needle)
                }
                .prefix(10)

            // 海报要单独取：见 WikipediaSummary 的说明。并发发起，逐条补齐。
            return await withTaskGroup(of: (Int, SearchResult).self) { group in
                for (offset, page) in candidates.enumerated() {
                    group.addTask {
                        let poster = await self.wikipediaLeadImage(
                            title: page.title,
                            language: language
                        )
                        let result = SearchResult(
                            title: page.title.removingWikipediaDisambiguation,
                            creator: nil,
                            year: self.extractYear(fromText: page.extract),
                            genre: nil,  // Wikipedia 摘要没有流派字段，保持 nil
                            coverURL: poster ?? page.thumbnail?.source,
                            synopsis: page.extract,
                            webURL: page.fullurl,
                            type: .movie,
                            albumName: nil,
                            appleMusicURL: nil
                        )
                        return (offset, result)
                    }
                }

                // 任务完成顺序不定，用原始下标还原搜索相关度排序。
                var collected: [(Int, SearchResult)] = []
                for await pair in group {
                    collected.append(pair)
                }
                return collected
                    .sorted { $0.0 < $1.0 }
                    .map(\.1)
            }
        } catch {
            logger.warning("Wikipedia 电影搜索失败: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    /// 取条目首图（海报）。失败就返回 nil，让调用方回退到别的来源。
    private func wikipediaLeadImage(title: String, language: String) async -> String? {
        guard let encoded = title.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://\(language).wikipedia.org/api/rest_v1/page/summary/\(encoded)")
        else { return nil }

        do {
            let summary: WikipediaSummary = try await fetch(url)
            return summary.thumbnail?.source ?? summary.originalimage?.source
        } catch {
            return nil
        }
    }

    // MARK: - 剧集搜索（TVMaze，无需 API 密钥）

    private func searchTVMaze(query: String) async -> [SearchResult] {
        var components = URLComponents(string: "https://api.tvmaze.com/search/shows")
        components?.queryItems = [URLQueryItem(name: "q", value: query)]
        guard let url = components?.url else { return [] }

        do {
            let response: [TVMazeSearchResult] = try await fetch(url)
            return response.prefix(12).map { result in
                let show = result.show
                return SearchResult(
                    title: show.name,
                    creator: nil,
                    year: extractYear(from: show.premiered),
                    genre: show.genres.isEmpty ? nil : show.genres.joined(separator: " · "),
                    coverURL: show.image?.original ?? show.image?.medium,
                    synopsis: show.summary?.strippingHTML,
                    webURL: show.url,
                    type: .movie,
                    albumName: nil,
                    appleMusicURL: nil
                )
            }
        } catch {
            logger.warning("TVMaze 剧集搜索失败: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    // MARK: - 书籍搜索（Google Books API）

    private func searchBooks(query: String) async -> [SearchResult] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://www.googleapis.com/books/v1/volumes?q=\(encoded)&maxResults=20"
        guard let url = URL(string: urlString) else { return [] }

        do {
            let resp: GoogleBooksResponse = try await fetch(url)
            return (resp.items ?? []).compactMap { item in
                let info = item.volumeInfo
                guard let title = info.title, !title.isEmpty else { return nil }
                // Google Books 的 thumbnail 使用 http，替换为 https
                let coverURL = info.imageLinks?.thumbnail?
                    .replacingOccurrences(of: "http://", with: "https://")
                return SearchResult(
                    title: title,
                    creator: info.authors?.joined(separator: ", "),
                    year: extractYear(from: info.publishedDate),
                    genre: nil,
                    coverURL: coverURL,
                    synopsis: info.description,
                    webURL: info.previewLink ?? info.infoLink,
                    type: .book,
                    albumName: nil,
                    appleMusicURL: nil
                )
            }
        } catch {
            logger.warning("Google Books 搜索失败: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    // MARK: - 工具

    private func extractYear(from dateString: String?) -> Int? {
        guard let s = dateString, s.count >= 4,
              let year = Int(s.prefix(4)) else { return nil }
        return year
    }

    private func extractYear(fromText text: String?) -> Int? {
        guard let text,
              let range = text.range(of: #"\b(?:19|20)\d{2}\b"#, options: .regularExpression) else {
            return nil
        }
        return Int(text[range])
    }

    private func fetch<Response: Decodable>(_ url: URL) async throws -> Response {
        var request = URLRequest(url: url)
        request.setValue("ArtShelf/1.3 (macOS)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(Response.self, from: data)
    }
}

// MARK: - 去重

private extension Array where Element == SearchResult {
    func deduplicated() -> [SearchResult] {
        var seen = Set<String>()
        return filter { result in
            let key = result.title.lowercased() + "|" + (result.creator ?? "").lowercased()
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }
    }
}

private extension String {
    var containsCJK: Bool {
        unicodeScalars.contains { scalar in
            (0x4E00...0x9FFF).contains(scalar.value)
        }
    }

    var removingWikipediaDisambiguation: String {
        replacingOccurrences(of: #"\s*[（(](?:电影|電影|film)[）)]\s*$"#, with: "", options: [.regularExpression, .caseInsensitive])
    }

    var strippingHTML: String {
        replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
    }
}
