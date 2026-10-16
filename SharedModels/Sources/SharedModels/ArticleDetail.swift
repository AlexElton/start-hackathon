import Foundation

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
