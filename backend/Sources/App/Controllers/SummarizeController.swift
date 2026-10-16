import FeedEngine
import SharedModels
import Vapor

/// `POST /summarize`: streams an AI summary of an article as Server-Sent Events.
///
/// The request only carries `itemId`; the article is loaded from the repository here,
/// so the client never posts article text. Each Gemini text chunk is forwarded as
/// `data: {"delta": "…"}`, and the stream ends with `event: done`.
struct SummarizeController: RouteCollection {
    let repository: any ContentRepository
    let gemini: GeminiClient

    func boot(routes: any RoutesBuilder) throws {
        routes.post(.constant(API.Path.summarize), use: summarize)
    }

    @Sendable
    func summarize(req: Request) async throws -> Response {
        let request: SummarizeRequest
        do {
            request = try req.content.decode(SummarizeRequest.self)
        } catch {
            throw Abort(.badRequest, reason: "body must be {\"itemId\": \"…\"}")
        }
        guard let article = repository.article(id: request.itemId) else {
            throw Abort(.notFound, reason: "article not found")
        }

        // No key set (offline demo, tests): stream the article's own 3-bullet summary.
        guard gemini.isConfigured else {
            return SSEResponse.make(chunks: Self.fallbackChunks(for: article))
        }

        let stream = try await gemini.summarize(article: article)
        return SSEResponse.make(chunks: SSEResponse.deltas(from: stream))
    }

    /// The article's own 3-bullet summary, one chunk per bullet.
    static func fallbackChunks(for article: ArticleDetail) -> AsyncThrowingStream<SummaryDelta, Error> {
        let bullets = article.lead.map { [$0] } ?? []
        var iterator = bullets.makeIterator()
        return AsyncThrowingStream<SummaryDelta, Error> {
            iterator.next().map { SummaryDelta(delta: "\($0)\n\n") }
        }
    }
}

extension SummarizeRequest: @retroactive Content {}
