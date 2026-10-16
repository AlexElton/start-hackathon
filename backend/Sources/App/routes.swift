import FeedEngine
import SharedModels
import Vapor

func routes(_ app: Application, repository: any ContentRepository, now: @escaping @Sendable () -> Date) throws {
    let api = app.grouped(PathComponent(stringLiteral: "api"), "v1")

    api.get(.constant(API.Path.health)) { _ in "ok" }

    try api.register(collection: MetaController(repository: repository))
    try api.register(collection: FeedController(repository: repository, now: now))
    try api.register(collection: ArticleController(repository: repository))
}
