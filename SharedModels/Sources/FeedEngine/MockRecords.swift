import Foundation
import SharedModels

/// Our additions to a Polaris article: where it happened, category and a 3-bullet summary.
/// One entry per file in `Data/articles/`. Several locations give several pins.
struct ArticleMeta: Decodable {
    let id: String
    let categoryId: String
    let paperId: String
    let summary: [String]
    let locations: [GeoPoint]
    /// Our added articles are dated this many hours before the app starts, so "i dag" and "denne uka" always
    /// have news. The original Polaris exports keep their real dates.
    let hoursAgo: Double?
}

/// `events.json`. Dates are relative (`dayOffset` + "HH:mm") so "i kveld" always has events.
struct EventRecord: Decodable {
    let id: String
    let title: String
    let categoryId: String
    let paperId: String?
    let location: GeoPoint
    let imageUrl: String?
    let dayOffset: Int
    let startTime: String
    let endTime: String?
    let venue: String
    let price: String?
    let description: String?
    let tags: [String]?
}

/// `ads.json`. A deal is valid from today until the end of day `daysValid - 1`.
struct AdRecord: Decodable {
    let id: String
    let title: String
    let categoryId: String
    let paperId: String?
    let location: GeoPoint
    let imageUrl: String?
    let merchant: String
    let offer: String
    let daysValid: Int
    let description: String?
    let tags: [String]?
}

extension Calendar {
    /// All relative mock dates are resolved in Norwegian time.
    public static let oslo: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Oslo")!
        return calendar
    }()

    /// `dayOffset` days after the start of `now`'s day, at "HH:mm".
    func date(dayOffset: Int, time: String, relativeTo now: Date) -> Date? {
        let parts = time.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2,
              let day = date(byAdding: .day, value: dayOffset, to: startOfDay(for: now))
        else { return nil }
        return date(bySettingHour: parts[0], minute: parts[1], second: 0, of: day)
    }
}
