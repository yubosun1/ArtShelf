import Foundation
import os

/// 搜索结果统一模型
struct SearchResult: Identifiable, Sendable {
    let id = UUID()
    let title: String
    let creator: String?
    let year: Int?
    let genre: String?       // 流派 / 类型（如 Drama · Thriller）
    let coverURL: String?
    let synopsis: String?
    /// 资料页链接（豆瓣 / 维基 / TVMaze / 书店页，只读查阅；在线观看链接由用户手动补）
    let referenceURL: String?
    let type: MediaType
    let albumName: String?
    let appleMusicURL: String?
    /// 影视：剧集总集数（用于预填「按集」进度）；其他类型为 nil
    let episodeCount: Int?
}

// MARK: - iTunes Search API 响应

private struct ITunesResponse: Codable, Sendable {
    let resultCount: Int
    let results: [ITunesResult]
}

private struct ITunesResult: Codable, Sendable {
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

private struct GoogleBooksResponse: Codable, Sendable {
    let totalItems: Int
    let items: [GoogleBookItem]?
}

private struct GoogleBookItem: Codable, Sendable {
    let id: String
    let volumeInfo: VolumeInfo
}

private struct VolumeInfo: Codable, Sendable {
    let title: String?
    let authors: [String]?
    let description: String?
    let imageLinks: ImageLinks?
    let publishedDate: String?
    let previewLink: String?
    let infoLink: String?
}

private struct ImageLinks: Codable, Sendable {
    let smallThumbnail: String?
    let thumbnail: String?
}

// MARK: - Wikipedia API 响应

private struct WikipediaResponse: Decodable, Sendable {
    let query: WikipediaQuery?
}

private struct WikipediaQuery: Decodable, Sendable {
    let pages: [String: WikipediaPage]
}

private struct WikipediaPage: Decodable, Sendable {
    let pageid: Int
    let title: String
    let index: Int?
    let thumbnail: WikipediaThumbnail?
    let extract: String?
    let fullurl: String?
    let pageprops: WikipediaPageProps?
}

private struct WikipediaPageProps: Decodable, Sendable {
    let wikibase_item: String?
}

private struct WikipediaThumbnail: Decodable, Sendable {
    let source: String
}

/// REST `page/summary` 的响应。
///
/// 这个端点会返回条目的首图，**包括合理使用的非自由图片**——
/// 而 action API 的 `prop=pageimages` 只给自由许可的图，
/// 因此电影海报在那里永远是 nil。海报只能从这里拿。
private struct WikipediaSummary: Decodable, Sendable {
    let thumbnail: WikipediaThumbnail?
    let originalimage: WikipediaThumbnail?
}

// MARK: - TVMaze API 响应

private struct TVMazeSearchResult: Decodable, Sendable {
    let show: TVMazeShow
}

private struct TVMazeShow: Decodable, Sendable {
    let name: String
    let genres: [String]
    let premiered: String?
    let image: TVMazeImage?
    let summary: String?
    let url: String?
}

private struct TVMazeImage: Decodable, Sendable {
    let medium: String?
    let original: String?
}

// MARK: - 豆瓣 subject_suggest 响应（影视 / 书籍同一结构）

/// 豆瓣公开联想接口（无需 API Key）：华语影视与书籍覆盖最好，
/// 影视给标准 2:3 海报，书籍给作者 / 年份 / 封面。
private struct DoubanSuggestItem: Decodable, Sendable {
    let title: String
    let year: String?
    let img: String?        // 影视海报
    let pic: String?        // 书籍封面
    let url: String?
    let id: String?
    let episode: String?    // 影视集数
    let author_name: String?  // 书籍作者
}

// MARK: - Wikidata 响应（补全导演 / 类型 / 日期）

private struct WikidataEntitiesResponse: Decodable, Sendable {
    let entities: [String: WikidataEntity]?
}

private struct WikidataEntity: Decodable, Sendable {
    let claims: [String: [WikidataClaim]]?
    let labels: [String: WikidataLabel]?
}

private struct WikidataClaim: Decodable, Sendable {
    let mainsnak: WikidataSnak
}

private struct WikidataSnak: Decodable, Sendable {
    let datavalue: WikidataDatavalue?
}

/// 值是多态的（实体 id / 时间 / 字符串…），字符串等非对象值宽容降级为空
private struct WikidataDatavalue: Decodable, Sendable {
    let value: Value?

    struct Value: Decodable, Sendable {
        let id: String?     // 实体型：{"id": "Q…"}
        let time: String?   // 时间型：{"time": "+2007-01-08T00:00:00Z"}
    }

    private enum CodingKeys: String, CodingKey { case value }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        value = try? container.decode(Value.self, forKey: .value)
    }
}

private struct WikidataLabel: Decodable, Sendable {
    let value: String
}

/// 从 Wikidata 提炼出的影视事实字段
private struct WikidataFacts: Sendable {
    var director: String?
    var genre: String?
    var year: Int?
}

/// 元数据搜索服务
final class MetadataService: Sendable {

    static let shared = MetadataService()
    private init() {}

    private let logger = Logger(subsystem: "ArtShelf", category: "MetadataService")

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        // 8s 上限：个别源在用户网络下不可达（挂起到超时）时，不拖慢整体搜索
        config.timeoutIntervalForRequest = 8
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

    // MARK: - 影视搜索（电影 + 电视剧，多源合并）

    /// 豆瓣（华语覆盖最好、标准 2:3 海报）+ Wikipedia（简介，经 Wikidata 补导演/类型/日期）
    /// + Apple 剧集目录；TVMaze 华语覆盖薄、且部分网络不可达，中文查询跳过。
    ///
    /// 注意：iTunes 的 `media=movie` 已经下线，任何关键词都返回 0 条，
    /// 所以这里不再请求它——电影海报改由豆瓣 / Wikipedia REST 的首图提供。
    private func searchMoviesAndTV(query: String) async -> [SearchResult] {
        async let douban = searchDoubanMedia(query: query)
        // 华语作品影剧难分：「电影」关键词会把剧集页挤出前列（实测），
        // 中文查询并发跑「电视剧」「电影」两个关键词再合并；英文只用 film
        async let wikiTV: [SearchResult] = query.containsCJK
            ? searchWikipediaMovies(query: query, movieKeyword: "电视剧")
            : searchWikipediaMovies(query: query, movieKeyword: "film")
        async let wikiFilm: [SearchResult] = query.containsCJK
            ? searchWikipediaMovies(query: query, movieKeyword: "电影")
            : []
        async let appleTVShows = searchITunes(
            query: query,
            media: "tvShow",
            entity: "tvSeason",
            country: "us"
        )
        // TVMaze 对中文关键词命中差且可能不可达（挂到超时），只用于非中文查询
        async let tvMazeShows: [SearchResult] = query.containsCJK ? [] : searchTVMaze(query: query)

        // 源顺序即字段优先级：同名条目按序补缺合并
        // （豆瓣封面/年份/链接 → Wikipedia 简介与 Wikidata 字段 → iTunes → TVMaze）
        let sources = await [douban, wikiTV, wikiFilm, appleTVShows, tvMazeShows]
        let combined = mergeByTitle(sources)

        // 有海报的排前面——带图的条目更容易辨认
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
                    referenceURL: result.trackViewUrl ?? result.collectionViewUrl,
                    type: isMusic ? .music : .movie,
                    albumName: isMusic ? result.collectionName : nil,
                    appleMusicURL: isMusic ? result.collectionViewUrl : nil,
                    episodeCount: nil
                )
            }
        } catch {
            logger.warning("iTunes 搜索失败 [\(media, privacy: .public)]: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    // MARK: - 电影搜索（Wikipedia，无需 API 密钥）

    /// `movieKeyword` 为消歧关键词（中文：电影 / 电视剧；英文：film），
    /// 由调用方组合并发多个关键词以覆盖影剧两种形态
    private func searchWikipediaMovies(query: String, movieKeyword: String) async -> [SearchResult] {
        let language = query.containsCJK ? "zh" : "en"
        var components = URLComponents(string: "https://\(language).wikipedia.org/w/api.php")
        components?.queryItems = [
            URLQueryItem(name: "action", value: "query"),
            URLQueryItem(name: "generator", value: "search"),
            URLQueryItem(name: "gsrsearch", value: "\(query) \(movieKeyword)"),
            URLQueryItem(name: "gsrnamespace", value: "0"),
            URLQueryItem(name: "gsrlimit", value: "12"),
            URLQueryItem(name: "prop", value: "pageimages|extracts|info|pageprops"),
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
            var collected: [(Int, WikipediaPage, SearchResult)] = await withTaskGroup(
                of: (Int, WikipediaPage, SearchResult).self
            ) { group in
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
                            genre: nil,  // Wikipedia 摘要没有流派字段，由 Wikidata 补全
                            coverURL: poster ?? page.thumbnail?.source,
                            synopsis: page.extract,
                            referenceURL: page.fullurl,
                            type: .movie,
                            albumName: nil,
                            appleMusicURL: nil,
                            episodeCount: nil
                        )
                        return (offset, page, result)
                    }
                }

                // 任务完成顺序不定，用原始下标还原搜索相关度排序。
                var pairs: [(Int, WikipediaPage, SearchResult)] = []
                for await triple in group {
                    pairs.append(triple)
                }
                return pairs.sorted { $0.0 < $1.0 }
            }

            // Wikidata 补全导演 / 类型 / 日期（批量两次请求；失败静默降级）
            let items = collected.compactMap { $0.1.pageprops?.wikibase_item }
            if !items.isEmpty, let facts = try? await wikidataFacts(for: items) {
                for index in collected.indices {
                    guard let item = collected[index].1.pageprops?.wikibase_item,
                          let fact = facts[item] else { continue }
                    collected[index].2 = collected[index].2.filling(
                        creator: fact.director,
                        genre: fact.genre,
                        year: fact.year
                    )
                }
            }
            return collected.map(\.2)
        } catch {
            logger.warning("Wikipedia 电影搜索失败: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    /// 批量取 Wikidata 事实：一次 `wbgetentities?props=claims` 拿全部候选的声明，
    /// 再一次 `props=labels` 解析实体标签，避免逐条目请求放大延迟。
    private func wikidataFacts(for items: [String]) async throws -> [String: WikidataFacts] {
        var claimComponents = URLComponents(string: "https://www.wikidata.org/w/api.php")
        claimComponents?.queryItems = [
            URLQueryItem(name: "action", value: "wbgetentities"),
            URLQueryItem(name: "ids", value: items.joined(separator: "|")),
            URLQueryItem(name: "props", value: "claims"),
            URLQueryItem(name: "format", value: "json")
        ]
        guard let claimsURL = claimComponents?.url else { return [:] }
        let claimsResp: WikidataEntitiesResponse = try await fetch(claimsURL)
        guard let entities = claimsResp.entities else { return [:] }

        // 收集需要解析标签的实体（P57 导演 / P136 类型）
        var labelIDs = Set<String>()
        for entity in entities.values {
            for property in ["P57", "P136"] {
                for claim in entity.claims?[property] ?? [] {
                    if let id = claim.mainsnak.datavalue?.value?.id { labelIDs.insert(id) }
                }
            }
        }

        var labels: [String: String] = [:]
        if !labelIDs.isEmpty {
            var labelComponents = URLComponents(string: "https://www.wikidata.org/w/api.php")
            labelComponents?.queryItems = [
                URLQueryItem(name: "action", value: "wbgetentities"),
                URLQueryItem(name: "ids", value: labelIDs.joined(separator: "|")),
                URLQueryItem(name: "props", value: "labels"),
                URLQueryItem(name: "languages", value: "zh|en"),
                URLQueryItem(name: "format", value: "json")
            ]
            if let labelsURL = labelComponents?.url {
                // 标签解析失败只损失导演/类型的显示名，不影响年份等其他字段
                if let labelsResp: WikidataEntitiesResponse = try? await fetch(labelsURL) {
                    for (id, entity) in labelsResp.entities ?? [:] {
                        // 优先中文标签，无则英文
                        labels[id] = entity.labels?["zh"]?.value ?? entity.labels?["en"]?.value
                    }
                }
            }
        }

        var facts: [String: WikidataFacts] = [:]
        for (item, entity) in entities {
            var fact = WikidataFacts()

            let directors = (entity.claims?["P57"] ?? [])
                .compactMap { $0.mainsnak.datavalue?.value?.id }
                .compactMap { labels[$0] }
            if !directors.isEmpty {
                fact.director = Array(directors.prefix(3)).joined(separator: "、")
            }

            let genres = (entity.claims?["P136"] ?? [])
                .compactMap { $0.mainsnak.datavalue?.value?.id }
                .compactMap { labels[$0] }
            if !genres.isEmpty {
                fact.genre = Array(genres.prefix(3)).joined(separator: " · ")
            }

            if let time = entity.claims?["P577"]?.first?.mainsnak.datavalue?.value?.time {
                fact.year = extractYear(fromWikidataTime: time)
            }
            facts[item] = fact
        }
        return facts
    }

    /// Wikidata 时间形如 `+2007-01-08T00:00:00Z`，取年份
    private func extractYear(fromWikidataTime time: String) -> Int? {
        guard time.hasPrefix("+") else { return nil }
        let start = time.index(after: time.startIndex)
        guard let end = time.firstIndex(of: "-"), end > start else { return nil }
        return Int(time[start..<end])
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
                    referenceURL: show.url,
                    type: .movie,
                    albumName: nil,
                    appleMusicURL: nil,
                    episodeCount: nil
                )
            }
        } catch {
            logger.warning("TVMaze 剧集搜索失败: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    // MARK: - 豆瓣联想搜索（影视 / 书籍，无需 API 密钥）

    /// 影视：华语内容覆盖最好，直接给标准 2:3 海报、年份、集数与条目链接
    private func searchDoubanMedia(query: String) async -> [SearchResult] {
        await searchDoubanSuggest(host: "movie.douban.com", query: query) { item in
            SearchResult(
                title: item.title,
                creator: nil,
                year: item.year.flatMap(Int.init),
                genre: nil,
                // s_ratio_poster 小图 → m_ratio_poster 中图（实测存在且清晰得多）
                coverURL: item.img?.replacingOccurrences(of: "s_ratio_poster", with: "m_ratio_poster"),
                // 简介留空让给 Wikipedia 摘要（合并时只补空缺字段）；集数用于预填「按集」进度
                synopsis: nil,
                referenceURL: item.url?.removingQueryString,
                type: .movie,
                albumName: nil,
                appleMusicURL: nil,
                // 豆瓣「集数」字段：电影通常是 1，剧集为实际集数；>1 才作为剧集总量
                episodeCount: item.episode.flatMap(Int.init).flatMap { $0 > 1 ? $0 : nil }
            )
        }
    }

    /// 书籍：标题 + 作者 + 年份 + 封面，正好覆盖「搜到基本信息、本地再补文件」的流程
    private func searchDoubanBooks(query: String) async -> [SearchResult] {
        await searchDoubanSuggest(host: "book.douban.com", query: query) { item in
            SearchResult(
                title: item.title,
                creator: item.author_name,
                year: item.year.flatMap(Int.init),
                genre: nil,
                // 书籍封面小图 /view/subject/s/public/ → 大图 /l/public/
                coverURL: item.pic?.replacingOccurrences(of: "/view/subject/s/public/", with: "/view/subject/l/public/"),
                synopsis: nil,
                referenceURL: item.url?.removingQueryString,
                type: .book,
                albumName: nil,
                appleMusicURL: nil,
                episodeCount: nil
            )
        }
    }

    /// `subject_suggest` 公共请求：movie/book 两个子站同一接口同一结构
    private func searchDoubanSuggest(
        host: String,
        query: String,
        map: (DoubanSuggestItem) -> SearchResult
    ) async -> [SearchResult] {
        var components = URLComponents(string: "https://\(host)/j/subject_suggest")
        components?.queryItems = [URLQueryItem(name: "q", value: query)]
        guard let url = components?.url else { return [] }

        do {
            let response: [DoubanSuggestItem] = try await fetch(url)
            return response.prefix(12).map(map)
        } catch {
            logger.warning("豆瓣联想搜索失败 [\(host, privacy: .public)]: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    // MARK: - 书籍搜索（豆瓣 + Google Books 合并）

    /// 豆瓣优先（华语书籍覆盖好、本网络可达）；Google Books 兜底非中文与海外网络。
    private func searchBooks(query: String) async -> [SearchResult] {
        async let douban = searchDoubanBooks(query: query)
        async let google = searchGoogleBooks(query: query)
        let sources = await [douban, google]
        return Array(mergeByTitle(sources).prefix(30))
    }

    private func searchGoogleBooks(query: String) async -> [SearchResult] {
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
                    referenceURL: info.previewLink ?? info.infoLink,
                    type: .book,
                    albumName: nil,
                    appleMusicURL: nil,
                    episodeCount: nil
                )
            }
        } catch {
            logger.warning("Google Books 搜索失败: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    // MARK: - 工具

    /// 同名条目跨源合并：sources 顺序即字段优先级，
    /// 先见结果为准、后续来源只补空缺字段（封面 / 简介 / 导演 / 类型 / 年份 / 链接各取所长）
    private func mergeByTitle(_ sources: [[SearchResult]]) -> [SearchResult] {
        var order: [String] = []
        var merged: [String: SearchResult] = [:]
        for source in sources {
            for result in source {
                let key = result.title
                    .lowercased()
                    .replacingOccurrences(of: #"\s+"#, with: "", options: .regularExpression)
                if let existing = merged[key] {
                    merged[key] = existing.filling(from: result)
                } else {
                    merged[key] = result
                    order.append(key)
                }
            }
        }
        return order.compactMap { merged[$0] }
    }

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
        request.setValue("ArtShelf/3.0 (macOS)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(Response.self, from: data)
    }
}

// MARK: - 多源合并

private extension SearchResult {
    /// 复制并仅补空缺字段（已有值不被覆盖）
    func filling(creator: String? = nil, genre: String? = nil, year: Int? = nil) -> SearchResult {
        SearchResult(
            title: title,
            creator: self.creator ?? creator,
            year: self.year ?? year,
            genre: self.genre ?? genre,
            coverURL: coverURL,
            synopsis: synopsis,
            referenceURL: referenceURL,
            type: type,
            albumName: albumName,
            appleMusicURL: appleMusicURL,
            episodeCount: episodeCount
        )
    }

    /// 逐字段取先见非空值补全
    func filling(from other: SearchResult) -> SearchResult {
        SearchResult(
            title: title,
            creator: creator ?? other.creator,
            year: year ?? other.year,
            genre: genre ?? other.genre,
            coverURL: coverURL ?? other.coverURL,
            synopsis: synopsis ?? other.synopsis,
            referenceURL: referenceURL ?? other.referenceURL,
            type: type,
            albumName: albumName ?? other.albumName,
            appleMusicURL: appleMusicURL ?? other.appleMusicURL,
            episodeCount: episodeCount ?? other.episodeCount
        )
    }
}

private extension String {
    /// 去掉 URL 的 query 串（豆瓣联想链接带 ?suggest= 尾巴，入库前清理）
    var removingQueryString: String {
        guard let index = firstIndex(of: "?") else { return self }
        return String(self[..<index])
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
