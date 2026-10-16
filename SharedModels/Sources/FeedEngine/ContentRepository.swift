import Foundation
import SharedModels

/// A feed item plus the text that muted words are matched against (title and tags).
public struct IndexedFeedItem: Sendable {
    public var item: FeedItem
    public let searchText: String

    public init(item: FeedItem, tags: [String]) {
        self.item = item
        searchText = ([item.title] + tags).joined(separator: " ").lowercased()
    }
}

/// Read-only content source. A protocol so the JSON files can later be swapped for a database or a real Polaris API.
public protocol ContentRepository: Sendable {
    var categories: [SharedModels.Category] { get }
    var papers: [Paper] { get }
    /// Every article pin, event and deal, with relative dates resolved against `now`.
    func feedItems(now: Date) -> [IndexedFeedItem]
    func article(id: String) -> ArticleDetail?
}

public enum ContentError: Error, CustomStringConvertible {
    case missingArticleFile(String)
    case unknownCategory(String, in: String)
    case unknownPaper(String, in: String)
    case noLocation(String)
    case badTime(String, in: String)

    public var description: String {
        switch self {
        case .missingArticleFile(let id): "article-meta.json lists '\(id)' but articles/\(id).json is missing"
        case .unknownCategory(let category, let item): "'\(item)' uses unknown category '\(category)'"
        case .unknownPaper(let paper, let item): "'\(item)' uses unknown paper '\(paper)'"
        case .noLocation(let id): "article '\(id)' has no locations"
        case .badTime(let time, let item): "'\(item)' has bad time '\(time)', expected HH:mm"
        }
    }
}

/// Loads every JSON file from `Data/` into memory once, and validates the references between them.
public struct JSONContentRepository: ContentRepository {
    public let categories: [SharedModels.Category]
    public let papers: [Paper]
    private let articles: [String: ArticleDetail]
    private let articlePins: [IndexedFeedItem]
    private let events: [EventRecord]
    private let ads: [AdRecord]

    /// The mock data shipped inside this package. Used by both the app and the backend.
    public static func bundled() throws -> JSONContentRepository {
        guard let directory = Bundle.module.url(forResource: "Data", withExtension: nil) else {
            throw ContentError.missingArticleFile("Data")
        }
        return try JSONContentRepository(dataDirectory: directory.path)
    }

    public init(dataDirectory: String) throws {
        let base = URL(fileURLWithPath: dataDirectory)
        categories = try Self.load("categories.json", from: base)
        papers = try Self.load("papers.json", from: base)
        events = try Self.load("events.json", from: base)
        ads = try Self.load("ads.json", from: base)

        let categoryIds = Set(categories.map(\.id))
        let paperIds = Set(papers.map(\.id))
        func validate(category: String, paper: String?, item: String) throws {
            guard categoryIds.contains(category) else { throw ContentError.unknownCategory(category, in: item) }
            if let paper, !paperIds.contains(paper) { throw ContentError.unknownPaper(paper, in: item) }
        }

        var articles: [String: ArticleDetail] = [:]
        var pins: [IndexedFeedItem] = []
        let metas: [ArticleMeta] = try Self.load("article-meta.json", from: base)
        for meta in metas {
            try validate(category: meta.categoryId, paper: meta.paperId, item: meta.id)
            guard !meta.locations.isEmpty else { throw ContentError.noLocation(meta.id) }
            let file = base.appendingPathComponent("articles/\(meta.id).json")
            guard FileManager.default.fileExists(atPath: file.path) else { throw ContentError.missingArticleFile(meta.id) }
            let raw: PolarisArticle = try Self.load("articles/\(meta.id).json", from: base)

            articles[meta.id] = ArticleDetail(
                id: raw.id,
                title: raw.title.value,
                lead: raw.lead,
                body: raw.bodyParagraphs,
                author: raw.author,
                publishedAt: raw.changes.published,
                updatedAt: raw.changes.updated,
                paperId: meta.paperId,
                sourceUrl: raw.urls.canonical,
                imageUrl: raw.imageURL,
                categoryId: meta.categoryId,
                section: raw.section?.title,
                locations: meta.locations
            )

            let summary = meta.summary.isEmpty ? Array(raw.newsroomSummary.prefix(3)) : meta.summary
            let details = FeedItem.ArticleDetails(
                articleId: raw.id,
                lead: raw.lead ?? summary.first,
                summary: summary,
                readMinutes: raw.readMinutes
            )
            for (index, location) in meta.locations.enumerated() {
                let item = FeedItem(
                    id: meta.locations.count == 1 ? raw.id : "\(raw.id)-\(index + 1)",
                    title: raw.title.value,
                    categoryId: meta.categoryId,
                    paperId: meta.paperId,
                    location: location,
                    imageUrl: raw.imageURL,
                    date: raw.changes.published,
                    details: .article(details)
                )
                pins.append(IndexedFeedItem(item: item, tags: raw.tagTitles + [location.name ?? ""]))
            }
        }
        self.articles = articles
        articlePins = pins

        for event in events {
            try validate(category: event.categoryId, paper: event.paperId, item: event.id)
            for time in [event.startTime, event.endTime].compactMap({ $0 })
            where Calendar.oslo.date(dayOffset: 0, time: time, relativeTo: Date()) == nil {
                throw ContentError.badTime(time, in: event.id)
            }
        }
        for ad in ads {
            try validate(category: ad.categoryId, paper: ad.paperId, item: ad.id)
        }
    }

    public func article(id: String) -> ArticleDetail? {
        articles[id]
    }

    public func feedItems(now: Date) -> [IndexedFeedItem] {
        articlePins + events.compactMap { resolve($0, now: now) } + ads.compactMap { resolve($0, now: now) }
    }

    private func resolve(_ event: EventRecord, now: Date) -> IndexedFeedItem? {
        let calendar = Calendar.oslo
        guard let start = calendar.date(dayOffset: event.dayOffset, time: event.startTime, relativeTo: now) else { return nil }
        var end = event.endTime.flatMap { calendar.date(dayOffset: event.dayOffset, time: $0, relativeTo: now) }
        if let value = end, value <= start {
            end = calendar.date(byAdding: .day, value: 1, to: value) // Ends after midnight.
        }
        let item = FeedItem(
            id: event.id,
            title: event.title,
            categoryId: event.categoryId,
            paperId: event.paperId,
            location: event.location,
            imageUrl: event.imageUrl,
            date: start,
            details: .event(.init(startsAt: start, endsAt: end, venue: event.venue, price: event.price, description: event.description))
        )
        return IndexedFeedItem(item: item, tags: (event.tags ?? []) + [event.venue])
    }

    private func resolve(_ ad: AdRecord, now: Date) -> IndexedFeedItem? {
        let calendar = Calendar.oslo
        guard let endOfLastDay = calendar.date(byAdding: .day, value: max(ad.daysValid, 1), to: calendar.startOfDay(for: now)) else { return nil }
        let validUntil = endOfLastDay.addingTimeInterval(-1)
        let item = FeedItem(
            id: ad.id,
            title: ad.title,
            categoryId: ad.categoryId,
            paperId: ad.paperId,
            location: ad.location,
            imageUrl: ad.imageUrl,
            date: validUntil,
            details: .ad(.init(merchant: ad.merchant, offer: ad.offer, validUntil: validUntil, description: ad.description))
        )
        return IndexedFeedItem(item: item, tags: (ad.tags ?? []) + [ad.merchant])
    }

    private static func load<T: Decodable>(_ file: String, from base: URL) throws -> T {
        let data = try Data(contentsOf: base.appendingPathComponent(file))
        do {
            return try JSONDecoder.api.decode(T.self, from: data)
        } catch {
            throw DecodingFailure(file: file, underlying: error)
        }
    }
}

/// Names the file that failed, so a typo in mock data is easy to find.
public struct DecodingFailure: Error, CustomStringConvertible {
    let file: String
    let underlying: any Error

    public var description: String { "Could not decode \(file): \(underlying)" }
}
