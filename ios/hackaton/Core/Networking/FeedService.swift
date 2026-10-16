import FeedEngine
import Foundation
import SharedModels

/// Loads map and list content. `LocalFeedService` runs everything on the phone; `LiveFeedService`
/// talks to the Vapor backend (same engine, over HTTP); the mock powers previews.
protocol FeedServicing {
    func feed(_ filter: FeedFilter) async throws -> FeedPage
    func article(id: String) async throws -> ArticleDetail
    func papers() async throws -> [Paper]
}

/// Runs the content engine in the app: the bundled Polaris articles, events and deals, filtered and sorted
/// on the phone with the same `FeedQuery` the backend uses. No server or network needed (images still load from Polaris).
struct LocalFeedService: FeedServicing {
    private let repository: JSONContentRepository

    init() throws {
        repository = try JSONContentRepository.bundled()
    }

    func feed(_ filter: FeedFilter) async throws -> FeedPage {
        let now = Date()
        return FeedQuery(filter: filter, now: now).run(on: repository.feedItems(now: now))
    }

    func article(id: String) async throws -> ArticleDetail {
        guard let article = repository.article(id: id) else { throw URLError(.fileDoesNotExist) }
        return article
    }

    func papers() async throws -> [Paper] {
        repository.papers
    }
}

struct LiveFeedService: FeedServicing {
    let api: APIClient

    func feed(_ filter: FeedFilter) async throws -> FeedPage {
        try await api.get(API.Path.feed, query: filter.queryItems)
    }

    func article(id: String) async throws -> ArticleDetail {
        try await api.get("\(API.Path.articles)/\(id)")
    }

    func papers() async throws -> [Paper] {
        try await api.get(API.Path.papers)
    }
}

struct MockFeedService: FeedServicing {
    var items: [FeedItem] = FeedItem.samples

    func feed(_ filter: FeedFilter) async throws -> FeedPage {
        let matches = items.filter { item in
            (filter.kinds?.contains(item.kind) ?? true) && (filter.bbox?.contains(item.location) ?? true)
        }
        return FeedPage(items: matches, total: matches.count)
    }

    func article(id: String) async throws -> ArticleDetail {
        ArticleDetail(
            id: id,
            title: "En av byens beste butikker er en av byens beste spisesteder",
            lead: "Dette er en av de beste lunsjstedene i byen. Men det kan fremdeles bli bedre.",
            body: ["Lunken og smelta", "Lokalet er fint, med gode stoler, pent treverk og en rolig atmosfære."],
            author: "Alva Hognestad Alvestrand",
            publishedAt: .now,
            updatedAt: nil,
            paperId: "adressa",
            sourceUrl: "https://www.adressa.no/",
            imageUrl: "https://vcdn.polarismedia.no/d9b779ef-0832-3cad-93af-68c2050fd543?w=1000&fit=clip&q=80",
            categoryId: "mat",
            section: "Restaurantguiden",
            locations: []
        )
    }

    func papers() async throws -> [Paper] {
        [Paper(id: "adressa", name: "Adresseavisen", city: "Trondheim", location: GeoPoint(lat: 63.43, lon: 10.39), color: "#005379", regionId: "trondelag", level: .regional)]
    }
}

extension FeedItem {
    /// A few real items from the mock data, for previews.
    static let samples: [FeedItem] = [
        FeedItem(
            id: "31EkrM",
            title: "En av byens beste butikker er en av byens beste spisesteder",
            categoryId: "mat",
            paperId: "adressa",
            location: GeoPoint(lat: 63.4316, lon: 10.3972, name: "Te og Kaffehuset"),
            imageUrl: "https://vcdn.polarismedia.no/d9b779ef-0832-3cad-93af-68c2050fd543?w=1000&fit=clip&q=80",
            date: .now,
            details: .article(.init(
                articleId: "31EkrM",
                lead: "Dette er en av de beste lunsjstedene i byen. Men det kan fremdeles bli bedre.",
                summary: ["Te og Kaffehuset har åpnet for servering.", "Anmelderen kårer cortadoen til byens beste.", "Treg service trekker ned."],
                readMinutes: 3
            ))
        ),
        FeedItem(
            id: "OgnOdV",
            title: "– Jeg tenkte at dette ikke var noe for meg",
            categoryId: "helse",
            paperId: "adressa",
            location: GeoPoint(lat: 63.4209, lon: 10.3887, name: "St. Olavs hospital"),
            imageUrl: "https://vcdn.polarismedia.no/5efbed9a-4ac9-340a-a9d4-3836e9741590?w=1000&fit=clip&q=80",
            date: .now,
            details: .article(.init(articleId: "OgnOdV", summary: [], readMinutes: 6))
        ),
        FeedItem(
            id: "evt_quiz_lyche",
            title: "Studentquiz på Lyche",
            categoryId: "studentliv",
            paperId: "adressa",
            location: GeoPoint(lat: 63.4224, lon: 10.3950, name: "Studentersamfundet"),
            imageUrl: "https://vcdn.polarismedia.no/f45e0d8d-4ec3-368a-b4f1-8bb05810ee0f?w=1000&fit=clip&q=80",
            date: .now,
            details: .event(.init(startsAt: .now, endsAt: nil, venue: "Lyche", price: "Gratis", description: nil))
        ),
    ]
}
