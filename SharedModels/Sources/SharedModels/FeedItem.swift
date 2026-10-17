import Foundation

/// One pin on the map or one row in the list. `kind` decides what `details` holds.
public struct FeedItem: Codable, Identifiable, Hashable, Sendable {
    public var id: String
    public var title: String
    public var categoryId: String
    public var paperId: String?
    /// Nil for articles that cannot be placed on the map (shown in the side panel instead).
    public var location: GeoPoint?
    public var imageUrl: String?
    /// Published time for articles, start time for events, valid-until for ads.
    public var date: Date
    /// Only set when the request had `near`.
    public var distanceKm: Double?
    public var details: Details

    public var kind: ItemKind { details.kind }

    public init(
        id: String,
        title: String,
        categoryId: String,
        paperId: String?,
        location: GeoPoint?,
        imageUrl: String?,
        date: Date,
        distanceKm: Double? = nil,
        details: Details
    ) {
        self.id = id
        self.title = title
        self.categoryId = categoryId
        self.paperId = paperId
        self.location = location
        self.imageUrl = imageUrl
        self.date = date
        self.distanceKm = distanceKm
        self.details = details
    }

    public enum Details: Hashable, Sendable {
        case article(ArticleDetails)
        case event(EventDetails)
        case ad(AdDetails)

        public var kind: ItemKind {
            switch self {
            case .article: .article
            case .event: .event
            case .ad: .ad
            }
        }
    }

    public struct ArticleDetails: Codable, Hashable, Sendable {
        /// The article to load with `GET /articles/:id`. One article can have several pins.
        public var articleId: String
        /// One or two sentences for the short sheet: the newsroom's lead, or the first bullet.
        public var lead: String?
        /// Three short bullets for the card.
        public var summary: [String]
        public var readMinutes: Int

        public init(articleId: String, lead: String? = nil, summary: [String], readMinutes: Int) {
            self.articleId = articleId
            self.lead = lead
            self.summary = summary
            self.readMinutes = readMinutes
        }
    }

    public struct EventDetails: Codable, Hashable, Sendable {
        public var startsAt: Date
        public var endsAt: Date?
        public var venue: String
        public var price: String?
        public var description: String?

        public init(startsAt: Date, endsAt: Date?, venue: String, price: String?, description: String?) {
            self.startsAt = startsAt
            self.endsAt = endsAt
            self.venue = venue
            self.price = price
            self.description = description
        }
    }

    public struct AdDetails: Codable, Hashable, Sendable {
        public var merchant: String
        public var offer: String
        public var validUntil: Date
        public var description: String?

        public init(merchant: String, offer: String, validUntil: Date, description: String?) {
            self.merchant = merchant
            self.offer = offer
            self.validUntil = validUntil
            self.description = description
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id, kind, title, categoryId, paperId, location, imageUrl, date, distanceKm, details
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        categoryId = try container.decode(String.self, forKey: .categoryId)
        paperId = try container.decodeIfPresent(String.self, forKey: .paperId)
        location = try container.decodeIfPresent(GeoPoint.self, forKey: .location)
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
        date = try container.decode(Date.self, forKey: .date)
        distanceKm = try container.decodeIfPresent(Double.self, forKey: .distanceKm)

        // Read `kind` first, then decode `details` as the matching type.
        switch try container.decode(ItemKind.self, forKey: .kind) {
        case .article: details = .article(try container.decode(ArticleDetails.self, forKey: .details))
        case .event: details = .event(try container.decode(EventDetails.self, forKey: .details))
        case .ad: details = .ad(try container.decode(AdDetails.self, forKey: .details))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(kind, forKey: .kind)
        try container.encode(title, forKey: .title)
        try container.encode(categoryId, forKey: .categoryId)
        try container.encodeIfPresent(paperId, forKey: .paperId)
        try container.encodeIfPresent(location, forKey: .location)
        try container.encodeIfPresent(imageUrl, forKey: .imageUrl)
        try container.encode(date, forKey: .date)
        try container.encodeIfPresent(distanceKm, forKey: .distanceKm)
        switch details {
        case .article(let value): try container.encode(value, forKey: .details)
        case .event(let value): try container.encode(value, forKey: .details)
        case .ad(let value): try container.encode(value, forKey: .details)
        }
    }
}

/// Response of `GET /feed`. `total` counts matches before `limit` was applied.
public struct FeedPage: Codable, Hashable, Sendable {
    public var items: [FeedItem]
    public var total: Int

    public init(items: [FeedItem], total: Int) {
        self.items = items
        self.total = total
    }
}
