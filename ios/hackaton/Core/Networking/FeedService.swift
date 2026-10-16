import FeedEngine
import Foundation
import SharedModels

/// Loads map and list content. `LocalFeedService` runs everything on the phone; `LiveFeedService`
/// talks to the Vapor backend (same engine, over HTTP); the mock powers previews.
protocol FeedServicing {
    func feed(_ filter: FeedFilter) async throws -> FeedPage
    func article(id: String) async throws -> ArticleDetail
    func papers() async throws -> [Paper]
    func categories() async throws -> [SharedModels.Category]
    /// GeoJSON, one feature per fylke.
    func regions() async throws -> Data
    /// GeoJSON, Norway as one outline.
    func norwayOutline() async throws -> Data
    /// Written summaries: today, this week, topics and places.
    func digests() async throws -> [Digest]
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

    func categories() async throws -> [SharedModels.Category] {
        repository.categories
    }

    func regions() async throws -> Data {
        repository.regionsGeoJSON
    }

    func norwayOutline() async throws -> Data {
        repository.norwayGeoJSON
    }

    func digests() async throws -> [Digest] {
        repository.digests
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

    func categories() async throws -> [SharedModels.Category] {
        try await api.get(API.Path.categories)
    }

    func regions() async throws -> Data {
        let (data, _) = try await api.session.data(from: api.baseURL.appending(path: API.Path.regions))
        return data
    }

    func norwayOutline() async throws -> Data {
        let (data, _) = try await api.session.data(from: api.baseURL.appending(path: API.Path.norway))
        return data
    }

    func digests() async throws -> [Digest] {
        try await api.get(API.Path.digests)
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
        try await LocalFeedService().papers()
    }

    func categories() async throws -> [SharedModels.Category] {
        try await LocalFeedService().categories()
    }

    func regions() async throws -> Data {
        try await LocalFeedService().regions()
    }

    func norwayOutline() async throws -> Data {
        try await LocalFeedService().norwayOutline()
    }

    func digests() async throws -> [Digest] {
        try await LocalFeedService().digests()
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
