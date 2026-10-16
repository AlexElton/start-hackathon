import FeedEngine
import SharedModels
import Vapor

/// `now` is injectable so tests can pin "tonight" to a fixed time, and `gemini` so tests
/// run without a key (canned fallback) even when GEMINI_API_KEY is set on the machine.
func configure(
    _ app: Application,
    now: @escaping @Sendable () -> Date = Date.init,
    gemini: GeminiClient? = nil
) async throws {
    app.http.server.configuration.hostname = Environment.get("HOST") ?? "0.0.0.0"
    app.http.server.configuration.port = Environment.get("PORT").flatMap(Int.init) ?? 8080

    ContentConfiguration.global.use(encoder: JSONEncoder.api, for: .json)
    ContentConfiguration.global.use(decoder: JSONDecoder.api, for: .json)

    // The mock data ships inside the FeedEngine package (SharedModels/Sources/FeedEngine/Data),
    // the same content the app runs on the phone. Loaded once at startup.
    let repository = try JSONContentRepository.bundled()
    app.logger.info("Loaded \(repository.categories.count) categories, \(repository.papers.count) papers, \(repository.feedItems(now: now()).count) feed items")

    try routes(
        app,
        repository: repository,
        now: now,
        gemini: gemini ?? GeminiClient(
            apiKey: Environment.get("GEMINI_API_KEY"),
            model: Environment.get("GEMINI_MODEL") ?? "gemini-flash-latest"
        )
    )
}
