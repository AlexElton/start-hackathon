import Foundation
import Observation
import SharedModels

/// The Sammendrag page: written digests for today, this week, topics and places, ordered for this user,
/// plus the articles, events and deals they link to.
@Observable
final class SummaryViewModel {
    private(set) var state: LoadState<Void> = .idle
    private(set) var digests: [Digest] = []
    var selectedId: String?
    /// Article pins by article id, so a point can open the reader.
    private var articles: [String: FeedItem] = [:]
    /// Events and deals by id.
    private var items: [String: FeedItem] = [:]
    private var paperNames: [String: String] = [:]

    let feed: any FeedServicing

    init(feed: any FeedServicing) {
        self.feed = feed
    }

    func load(settings: SettingsStore) async {
        if case .loaded = state {} else { state = .loading }
        do {
            async let all = feed.digests()
            async let articlePage = feed.feed(FeedFilter(kinds: [.article], limit: FeedFilter.maxLimit))
            async let otherPage = feed.feed(FeedFilter(kinds: [.event, .ad], limit: FeedFilter.maxLimit))
            async let papers = feed.papers()
            digests = Self.ordered(try await all, for: settings)
            articles = Dictionary(try await articlePage.items.compactMap { item in
                if case .article(let details) = item.details { return (details.articleId, item) }
                return nil
            }, uniquingKeysWith: { first, _ in first })
            items = Dictionary(try await otherPage.items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            let loadedPapers = try await papers
            paperNames = Dictionary(loadedPapers.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
            PaperLogos.register(loadedPapers)
            if selectedId == nil || !digests.contains(where: { $0.id == selectedId }) {
                selectedId = digests.first?.id
            }
            state = .loaded(())
        } catch {
            state = .failed("Fikk ikke hentet sammendragene")
        }
    }

    /// Today and this week first, then the user's own region, then their interests, then the rest.
    /// Topics they blacklisted are left out.
    static func ordered(_ digests: [Digest], for settings: SettingsStore) -> [Digest] {
        let blocked = Set(settings.blockedCategories)
        let preferred = Set(settings.preferredCategories)
        func rank(_ digest: Digest) -> Int {
            switch digest.scope {
            case .day: 0
            case .week: 1
            case .place: digest.regionId == settings.regionId ? 2 : 5
            case .category: preferred.contains(digest.categoryId ?? "") ? 3 : 4
            }
        }
        return digests
            .filter { !blocked.contains($0.categoryId ?? "") }
            .enumerated()
            .sorted { (rank($0.element), $0.offset) < (rank($1.element), $1.offset) }
            .map(\.element)
    }

    func article(for id: String?) -> FeedItem? {
        id.flatMap { articles[$0] }
    }

    func items(for digest: Digest) -> [FeedItem] {
        digest.itemIds.compactMap { items[$0] }
    }

    func paperName(for id: String?) -> String {
        id.flatMap { paperNames[$0] } ?? "Adresseavisen"
    }
}
