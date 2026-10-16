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
            return Self.sseResponse(chunks: Self.fallbackChunks(for: article))
        }

        let stream = try await gemini.summarize(article: article)
        return Self.sseResponse(chunks: AsyncThrowingStream<SummaryDelta, Error> { continuation in
            let task = Task {
                do {
                    for try await delta in stream {
                        continuation.yield(SummaryDelta(delta: delta))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        })
    }

    /// The article's own 3-bullet summary, one chunk per bullet.
    static func fallbackChunks(for article: ArticleDetail) -> AsyncThrowingStream<SummaryDelta, Error> {
        let bullets = article.lead.map { [$0] } ?? []
        var iterator = bullets.makeIterator()
        return AsyncThrowingStream<SummaryDelta, Error> {
            iterator.next().map { SummaryDelta(delta: "\($0)\n\n") }
        }
    }

    /// Wraps chunks in an SSE response: `text/event-stream`, no caching, `event: done` at the end.
    static func sseResponse(
        chunks: AsyncThrowingStream<SummaryDelta, Error>
    ) -> Response {
        let body = Response.Body(managedAsyncStream: { writer in
            do {
                for try await chunk in chunks {
                    let data = try JSONEncoder.api.encode(chunk)
                    try await writer.write(.buffer(ByteBuffer(data: Data("data: ".utf8) + data + Data("\n\n".utf8))))
                }
                try await writer.write(.buffer(ByteBuffer(string: "event: done\ndata: {}\n\n")))
                try await writer.write(.end)
            } catch {
                let payload = "event: error\ndata: {\"reason\": \"Gemini is unavailable\"}\n\n"
                try? await writer.write(.buffer(ByteBuffer(string: payload)))
                try? await writer.write(.end)
            }
        })
        let response = Response(status: .ok, body: body)
        response.headers.replaceOrAdd(name: .contentType, value: "text/event-stream")
        response.headers.replaceOrAdd(name: .cacheControl, value: "no-cache")
        return response
    }
}

extension SummarizeRequest: @retroactive Content {}
