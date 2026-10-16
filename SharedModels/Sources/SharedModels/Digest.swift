import Foundation

/// A written summary ("sammendrag") of several stories: for a period (today, this week),
/// a topic (kultur, blålys) or a place (Trondheim, Trøndelag). Response of `GET /digests`.
public struct Digest: Codable, Identifiable, Hashable, Sendable {
    public enum Scope: String, Codable, Sendable {
        case day, week, category, place
    }

    /// One numbered point. Links to the article it summarises, if any.
    public struct Point: Codable, Hashable, Sendable {
        public var title: String
        public var text: String
        public var articleId: String?

        public init(title: String, text: String, articleId: String? = nil) {
            self.title = title
            self.text = text
            self.articleId = articleId
        }
    }

    public var id: String
    public var scope: Scope
    /// Short name for the selector, e.g. "I dag", "Kultur".
    public var title: String
    /// Small label above the headline. For `day`/`week` the app shows the date or week number instead.
    public var kicker: String?
    public var headline: String
    public var intro: String
    public var points: [Point]
    /// Events and deals that belong with this summary (ids from events.json / ads.json).
    public var itemIds: [String]
    public var imageUrl: String?
    /// SF Symbol for the selector.
    public var symbol: String
    /// Hex accent colour.
    public var color: String
    /// Set for topic digests; used to put the user's interests first.
    public var categoryId: String?
    /// Set for place digests; used to put the user's region first.
    public var regionId: String?
    public var readMinutes: Int

    public init(id: String, scope: Scope, title: String, kicker: String?, headline: String, intro: String, points: [Point], itemIds: [String], imageUrl: String?, symbol: String, color: String, categoryId: String?, regionId: String?, readMinutes: Int) {
        self.id = id
        self.scope = scope
        self.title = title
        self.kicker = kicker
        self.headline = headline
        self.intro = intro
        self.points = points
        self.itemIds = itemIds
        self.imageUrl = imageUrl
        self.symbol = symbol
        self.color = color
        self.categoryId = categoryId
        self.regionId = regionId
        self.readMinutes = readMinutes
    }
}
