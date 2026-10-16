@testable import App
import FeedEngine
import SharedModels
import XCTVapor

final class APITests: XCTestCase {
    /// Thursday 16 October 2026, 12:00 in Oslo. "Tonight" is pinned so the tests don't depend on the clock.
    static let noon = Calendar.oslo.date(from: DateComponents(year: 2026, month: 10, day: 16, hour: 12))!

    private var app: Application!

    override func setUp() async throws {
        app = try await Application.make(.testing)
        try await configure(app, now: { Self.noon })
    }

    override func tearDown() async throws {
        try await app.asyncShutdown()
        app = nil
    }

    private func feed(_ query: String = "") async throws -> FeedPage {
        var page: FeedPage?
        try await app.test(.GET, "api/v1/feed\(query)") { res async throws in
            XCTAssertEqual(res.status, .ok, res.body.string)
            page = try JSONDecoder.api.decode(FeedPage.self, from: res.body)
        }
        return try XCTUnwrap(page)
    }

    func testHealth() async throws {
        try await app.test(.GET, "api/v1/health") { res async in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, "ok")
        }
    }

    func testFeedReturnsEveryPinEventAndDeal() async throws {
        let page = try await feed()
        XCTAssertEqual(page.total, 30)
        XCTAssertEqual(page.items.filter { $0.kind == .article }.count, 22)
        XCTAssertEqual(page.items.filter { $0.kind == .event }.count, 4)
        XCTAssertEqual(page.items.filter { $0.kind == .ad }.count, 4)
        XCTAssertEqual(Set(page.items.map(\.id)).count, page.items.count, "ids must be unique")
    }

    func testArticleWithSeveralLocationsGetsOnePinEach() async throws {
        let pins = try await feed("?kinds=article").items.filter {
            if case .article(let details) = $0.details { return details.articleId == "16grxK" }
            return false
        }
        XCTAssertEqual(pins.count, 10)
        XCTAssertEqual(pins.first?.id, "16grxK-1")
    }

    func testTonightIsEventsAfterFourAndDeals() async throws {
        let page = try await feed("?when=tonight")
        XCTAssertEqual(Set(page.items.filter { $0.kind == .event }.map(\.id)), ["evt_quiz_lyche", "evt_smashburger_hammerhead"])
        XCTAssertFalse(page.items.contains { $0.kind == .article })
        XCTAssertEqual(page.items.filter { $0.kind == .ad }.count, 4)
    }

    func testNearFillsDistanceAndRadiusFilters() async throws {
        let page = try await feed("?near=63.4183,10.4045&radiusKm=1&sort=distance")
        XCTAssertFalse(page.items.isEmpty)
        let distances = page.items.compactMap(\.distanceKm)
        XCTAssertEqual(distances.count, page.items.count)
        XCTAssertEqual(distances, distances.sorted())
        XCTAssertTrue(distances.allSatisfy { $0 <= 1 })
    }

    func testRelevancePutsPreferredCategoriesFirst() async throws {
        let page = try await feed("?sort=relevance&prefer=helse")
        XCTAssertEqual(page.items.prefix(2).map(\.categoryId), ["helse", "helse"])
    }

    func testCategoryExcludeMuteAndKinds() async throws {
        let krim = try await feed("?categories=krim")
        XCTAssertTrue(krim.items.allSatisfy { $0.categoryId == "krim" })
        let noKrim = try await feed("?exclude=krim")
        XCTAssertFalse(noKrim.items.contains { $0.categoryId == "krim" })
        let muted = try await feed("?mute=burger")
        XCTAssertFalse(muted.items.contains { $0.title.lowercased().contains("burger") })
        let noArticles = try await feed("?kinds=event,ad")
        XCTAssertTrue(noArticles.items.allSatisfy { $0.kind != .article })
    }

    func testBoundingBoxAndLimit() async throws {
        let bakklandet = try await feed("?bbox=63.427,10.400,63.431,10.406")
        XCTAssertEqual(Set(bakklandet.items.map(\.location.name)), ["Den Gode Nabo, Bakklandet", "Daglig Deig, Bakklandet", "Burger.no, Nedre Bakklandet"])
        let limited = try await feed("?limit=3")
        XCTAssertEqual(limited.items.count, 3)
        XCTAssertEqual(limited.total, 30)
    }

    func testBadQueryIsRejected() async throws {
        for query in ["?sort=distance", "?kinds=pizza", "?bbox=1,2,3", "?when=later", "?limit=0"] {
            try await app.test(.GET, "api/v1/feed\(query)") { res async in
                XCTAssertEqual(res.status, .badRequest, query)
            }
        }
    }

    func testEveryArticleLoadsWithBody() async throws {
        for id in ["16grxK", "316lpP", "31EkrM", "aJy014", "BM0E00", "eG5bky", "eGz299", "JO8X9P", "OgnOdV", "zlxvg5"] {
            try await app.test(.GET, "api/v1/articles/\(id)") { res async throws in
                XCTAssertEqual(res.status, .ok, id)
                let article = try JSONDecoder.api.decode(ArticleDetail.self, from: res.body)
                XCTAssertFalse(article.body.isEmpty, id)
                XCTAssertNotNil(article.imageUrl, id)
                XCTAssertTrue(article.sourceUrl.hasPrefix("https://www.adressa.no/"), id)
            }
        }
    }

    func testRegionsAreGeoJSONWithPolarisZones() async throws {
        try await app.test(.GET, "api/v1/regions") { res async throws in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.headers.contentType?.description, "application/geo+json")
            let json = try JSONSerialization.jsonObject(with: Data(buffer: res.body)) as? [String: Any]
            let features = try XCTUnwrap(json?["features"] as? [[String: Any]])
            XCTAssertEqual(features.count, 11) // 2020–2023 fylker
            let properties = features.compactMap { $0["properties"] as? [String: Any] }
            let papers = properties.compactMap { $0["regionalPaperId"] as? String }
            XCTAssertEqual(Set(papers), ["adressa", "smp", "itromso", "fvn"])
            let selectable = properties.filter { $0["selectable"] as? Bool == true }.compactMap { $0["id"] as? String }
            XCTAssertEqual(Set(selectable), ["trondelag", "more-og-romsdal", "troms-og-finnmark", "agder"])
        }
    }

    func testEveryPaperBelongsToARegion() async throws {
        let regions = Set(["trondelag", "more-og-romsdal", "troms-og-finnmark", "agder"])
        try await app.test(.GET, "api/v1/papers") { res async throws in
            let papers = try JSONDecoder.api.decode([Paper].self, from: res.body)
            XCTAssertEqual(papers.count, 21)
            XCTAssertTrue(papers.allSatisfy { regions.contains($0.regionId) })
        }
    }

    func testDigestsCoverPeriodsTopicsAndPlaces() async throws {
        try await app.test(.GET, "api/v1/digests") { res async throws in
            XCTAssertEqual(res.status, .ok)
            let digests = try JSONDecoder.api.decode([SharedModels.Digest].self, from: res.body)
            XCTAssertEqual(digests.count, 8)
            XCTAssertEqual(Set(digests.map(\.scope)), [.day, .week, .category, .place])
            XCTAssertTrue(digests.allSatisfy { !$0.points.isEmpty })
        }
        try await app.test(.GET, "api/v1/digests/kultur") { res async throws in
            XCTAssertEqual(try JSONDecoder.api.decode(SharedModels.Digest.self, from: res.body).categoryId, "kultur")
        }
        try await app.test(.GET, "api/v1/digests/nope") { res async in
            XCTAssertEqual(res.status, .notFound)
        }
    }

    func testUnknownArticleIs404() async throws {
        try await app.test(.GET, "api/v1/articles/nope") { res async in
            XCTAssertEqual(res.status, .notFound)
        }
    }

    func testFeedItemRoundTripsThroughJSON() throws {
        let item = FeedItem(
            id: "evt_1", title: "Quiz", categoryId: "studentliv", paperId: "adressa",
            location: GeoPoint(lat: 63.42, lon: 10.39), imageUrl: nil, date: Self.noon,
            details: .event(.init(startsAt: Self.noon, endsAt: nil, venue: "Klubben", price: "Gratis", description: nil))
        )
        let data = try JSONEncoder.api.encode(item)
        XCTAssertEqual(try JSONDecoder.api.decode(FeedItem.self, from: data), item)
        XCTAssertTrue(String(decoding: data, as: UTF8.self).contains(#""kind":"event""#))
    }
}
