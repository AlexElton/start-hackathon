import FeedEngine
import SharedModels
import Vapor

/// `POST /explain`: streams a short AI explanation of a selected term as Server-Sent Events.
///
/// The request carries the term plus the paragraph and title as context, so names get resolved
/// correctly. Each Gemini text chunk is forwarded as `data: {"delta": "…"}`, and the stream ends
/// with `event: done`. No caching; every tap streams fresh.
struct ExplainController: RouteCollection {
    let gemini: GeminiClient

    func boot(routes: any RoutesBuilder) throws {
        routes.post(.constant(API.Path.explain), use: explain)
    }

    @Sendable
    func explain(req: Request) async throws -> Response {
        let request: ExplainRequest
        do {
            request = try req.content.decode(ExplainRequest.self)
        } catch {
            throw Abort(.badRequest, reason: "body must be {\"term\": \"…\", \"context\": \"…\", \"title\": \"…\", \"itemId\": \"…\"}")
        }
        guard request.isValid else {
            throw Abort(.badRequest, reason: "term must be 1–80 characters and context at most 2,000")
        }

        // No key set (offline demo, tests): a short canned explanation, so the tooltip still streams.
        guard gemini.isConfigured else {
            return SSEResponse.make(chunks: Self.fallbackChunks(for: request))
        }

        let stream = try await gemini.explain(request: request)
        return SSEResponse.make(chunks: SSEResponse.deltas(from: stream))
    }

    /// A canned explanation, one chunk per sentence, for when no Gemini key is configured.
    static func fallbackChunks(for request: ExplainRequest) -> AsyncThrowingStream<ExplanationDelta, Error> {
        let sentences = [
            "\(request.term) er et begrep fra saken «\(request.title)».",
            "Denne forklaringen vises uten AI-nøkkel, slik demoen fungerer også offline.",
        ]
        var iterator = sentences.makeIterator()
        return AsyncThrowingStream<ExplanationDelta, Error> {
            iterator.next().map { ExplanationDelta(delta: "\($0) ") }
        }
    }
}

extension ExplainRequest: @retroactive Content {}
