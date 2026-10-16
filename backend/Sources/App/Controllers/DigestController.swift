import FeedEngine
import SharedModels
import Vapor

/// `GET /digests` and `GET /digests/:id`: written summaries for today, this week, topics and places.
struct DigestController: RouteCollection {
    let repository: any ContentRepository

    func boot(routes: any RoutesBuilder) throws {
        routes.get(.constant(API.Path.digests)) { _ in repository.digests }
        routes.get(.constant(API.Path.digests), ":id") { req -> SharedModels.Digest in
            guard let id = req.parameters.get("id"), let digest = repository.digests.first(where: { $0.id == id }) else {
                throw Abort(.notFound, reason: "digest not found")
            }
            return digest
        }
    }
}

extension SharedModels.Digest: @retroactive Content {}
