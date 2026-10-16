import SharedModels
import Vapor

/// `GET /feed`: one endpoint for both the map (bbox) and the list (near + sort).
struct FeedController: RouteCollection {
    let repository: any ContentRepository
    let now: @Sendable () -> Date

    func boot(routes: any RoutesBuilder) throws {
        routes.get(.constant(API.Path.feed), use: feed)
    }

    @Sendable
    func feed(req: Request) async throws -> FeedPage {
        let filter: FeedFilter
        do {
            filter = try FeedFilter(query: try req.query.decode([String: String].self))
        } catch let error as FeedFilter.ParseError {
            throw Abort(.badRequest, reason: error.description)
        }
        let now = now()
        return FeedQuery(filter: filter, now: now).run(on: repository.feedItems(now: now))
    }
}

extension FeedPage: @retroactive Content {}
