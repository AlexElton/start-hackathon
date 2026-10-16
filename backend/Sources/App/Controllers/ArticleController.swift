import SharedModels
import Vapor

/// `GET /articles/:id`: the full article for "Les hele saken".
struct ArticleController: RouteCollection {
    let repository: any ContentRepository

    func boot(routes: any RoutesBuilder) throws {
        routes.get(.constant(API.Path.articles), ":id", use: article)
    }

    @Sendable
    func article(req: Request) async throws -> ArticleDetail {
        guard let id = req.parameters.get("id"), let article = repository.article(id: id) else {
            throw Abort(.notFound, reason: "article not found")
        }
        return article
    }
}

extension ArticleDetail: @retroactive Content {}
