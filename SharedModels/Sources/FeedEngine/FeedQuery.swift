import Foundation
import SharedModels

/// Applies a `FeedFilter` to the in-memory items: filter by kind, category, words, paper, area and time, then sort.
public struct FeedQuery: Sendable {
    public let filter: FeedFilter
    public let now: Date
    public var calendar: Calendar

    /// Within this distance an item counts as "near" for the relevance score.
    public static let nearbyKm = 5.0

    public init(filter: FeedFilter, now: Date, calendar: Calendar = .oslo) {
        self.filter = filter
        self.now = now
        self.calendar = calendar
    }

    public func run(on items: [IndexedFeedItem]) -> FeedPage {
        var matches = items.filter(isCurrent)
            .filter(matchesContent)
            .filter(matchesTime)
            .compactMap(withDistance)
        sort(&matches)
        return FeedPage(items: matches.prefix(filter.limit).map(\.item), total: matches.count)
    }

    /// Hides events that have ended and deals that have expired.
    private func isCurrent(_ indexed: IndexedFeedItem) -> Bool {
        switch indexed.item.details {
        case .article: true
        case .event(let event): (event.endsAt ?? event.startsAt.addingTimeInterval(3 * 3600)) > now
        case .ad(let ad): ad.validUntil > now
        }
    }

    private func matchesContent(_ indexed: IndexedFeedItem) -> Bool {
        let item = indexed.item
        if let kinds = filter.kinds, !kinds.contains(item.kind) { return false }
        if let categories = filter.categories, !categories.contains(item.categoryId) { return false }
        if filter.exclude.contains(item.categoryId) { return false }
        if filter.mute.contains(where: indexed.searchText.contains) { return false }
        if let paper = filter.paper, item.paperId != paper { return false }
        if let bbox = filter.bbox {
            // Unplaced articles never match an area; they are fetched without a bbox.
            guard let location = item.location, bbox.contains(location) else { return false }
        }
        return true
    }

    /// `tonight`: events starting today after 16:00 and deals valid today; no articles.
    /// `today`: events starting today, deals, and articles published today.
    /// `week`: events in the next 7 days, deals, and articles from the last 7 days.
    private func matchesTime(_ indexed: IndexedFeedItem) -> Bool {
        guard let when = filter.when else { return true }
        let startOfToday = calendar.startOfDay(for: now)
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday)!
        let eventWindow: Range<Date>
        let articleWindow: Range<Date>?
        switch when {
        case .tonight:
            eventWindow = calendar.date(bySettingHour: 16, minute: 0, second: 0, of: now)!..<startOfTomorrow
            articleWindow = nil
        case .today:
            eventWindow = startOfToday..<startOfTomorrow
            articleWindow = startOfToday..<startOfTomorrow
        case .week:
            eventWindow = startOfToday..<calendar.date(byAdding: .day, value: 7, to: startOfToday)!
            articleWindow = calendar.date(byAdding: .day, value: -7, to: now)!..<now.addingTimeInterval(1)
        }
        switch indexed.item.details {
        case .article: return articleWindow?.contains(indexed.item.date) ?? false
        case .event(let event): return eventWindow.contains(event.startsAt)
        case .ad: return true // Expired deals are already gone.
        }
    }

    /// Fills `distanceKm` when the request has `near`, and drops items outside `radiusKm`.
    private func withDistance(_ indexed: IndexedFeedItem) -> IndexedFeedItem? {
        guard let near = filter.near else { return indexed }
        // Unplaced articles have no distance to anything.
        guard let location = indexed.item.location else { return nil }
        var indexed = indexed
        let distance = near.distanceKm(to: location)
        if let radius = filter.radiusKm, distance > radius { return nil }
        indexed.item.distanceKm = (distance * 100).rounded() / 100
        return indexed
    }

    private func sort(_ items: inout [IndexedFeedItem]) {
        switch filter.sort {
        case .time:
            // Closest to now first: today's news and the next events before older or later ones.
            items.sort { abs($0.item.date.timeIntervalSince(now)) < abs($1.item.date.timeIntervalSince(now)) }
        case .distance:
            items.sort { ($0.item.distanceKm ?? .infinity) < ($1.item.distanceKm ?? .infinity) }
        case .relevance:
            items.sort {
                let (left, right) = (relevance($0.item), relevance($1.item))
                return left != right ? left > right : $0.item.date > $1.item.date
            }
        }
    }

    /// +2 if the category is one the user prefers, +1 if within 5 km. Ties go to the newest.
    public func relevance(_ item: FeedItem) -> Int {
        var score = 0
        if filter.prefer.contains(item.categoryId) { score += 2 }
        if let distance = item.distanceKm, distance <= Self.nearbyKm { score += 1 }
        return score
    }
}
