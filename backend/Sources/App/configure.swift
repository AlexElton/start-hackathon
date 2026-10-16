import SharedModels
import Vapor

/// `now` is injectable so tests can pin "tonight" to a fixed time.
func configure(_ app: Application, now: @escaping @Sendable () -> Date = Date.init) async throws {
    app.http.server.configuration.hostname = Environment.get("HOST") ?? "0.0.0.0"
    app.http.server.configuration.port = Environment.get("PORT").flatMap(Int.init) ?? 8080

    ContentConfiguration.global.use(encoder: JSONEncoder.api, for: .json)
    ContentConfiguration.global.use(decoder: JSONDecoder.api, for: .json)

    // Data lives in backend/Resources/Data and is loaded once at startup.
    let dataDirectory = app.directory.resourcesDirectory + "Data/"
    let repository = try JSONContentRepository(dataDirectory: dataDirectory)
    app.logger.info("Loaded \(repository.categories.count) categories, \(repository.papers.count) papers, \(repository.feedItems(now: now()).count) feed items")

    try routes(app, repository: repository, now: now)
}
