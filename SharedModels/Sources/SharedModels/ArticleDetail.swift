import Foundation

/// Request of `POST /summarize`: the backend loads the article itself, so the client only sends the id.
public struct SummarizeRequest: Codable, Hashable, Sendable {
    public var itemId: String

    public init(itemId: String) {
        self.itemId = itemId
    }
}

/// One streamed chunk of the AI summary, sent as `data:` in the SSE response.
public struct SummaryDelta: Codable, Hashable, Sendable {
    public var delta: String

    public init(delta: String) {
        self.delta = delta
    }
}

/// Response of `GET /articles/:id`: the full article for the reader.
public struct ArticleDetail: Codable, Identifiable, Hashable, Sendable {
    public var id: String
    public var title: String
    public var lead: String?
    /// Plain-text paragraphs in reading order. Sub-headings are their own entries.
    public var body: [String]
    public var author: String?
    public var publishedAt: Date
    public var updatedAt: Date?
    public var paperId: String
    public var sourceUrl: String
    public var imageUrl: String?
    public var categoryId: String
    public var section: String?
    public var locations: [GeoPoint]

    public init(
        id: String,
        title: String,
        lead: String?,
        body: [String],
        author: String?,
        publishedAt: Date,
        updatedAt: Date?,
        paperId: String,
        sourceUrl: String,
        imageUrl: String?,
        categoryId: String,
        section: String?,
        locations: [GeoPoint]
    ) {
        self.id = id
        self.title = title
        self.lead = lead
        self.body = body
        self.author = author
        self.publishedAt = publishedAt
        self.updatedAt = updatedAt
        self.paperId = paperId
        self.sourceUrl = sourceUrl
        self.imageUrl = imageUrl
        self.categoryId = categoryId
        self.section = section
        self.locations = locations
    }
}
