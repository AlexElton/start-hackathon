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

/// Request of `POST /explain`: the selected term plus the text around it, so names get resolved correctly.
public struct ExplainRequest: Codable, Hashable, Sendable {
    /// The word, name or place the user selected. 1–80 characters.
    public var term: String
    /// The paragraph the term was selected in. At most 2,000 characters.
    public var context: String
    /// The article title, so "formannskapet" is explained in the right municipality.
    public var title: String
    /// The item the term came from, for traceability.
    public var itemId: String

    public init(term: String, context: String, title: String, itemId: String) {
        self.term = term
        self.context = context
        self.title = title
        self.itemId = itemId
    }

    /// The input rules from the API design: term 1–80 characters, context at most 2,000.
    public var isValid: Bool {
        (1...80).contains(term.count) && context.count <= 2_000
    }
}

/// One streamed chunk of the AI explanation, sent as `data:` in the SSE response.
public struct ExplanationDelta: Codable, Hashable, Sendable {
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
