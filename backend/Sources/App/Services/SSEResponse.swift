import SharedModels
import Vapor

/// Wraps a stream of deltas in an SSE response: `text/event-stream`, no caching,
/// each chunk as `data: {"delta": "…"}`, and `event: done` at the end.
/// If the stream throws mid-way, an `event: error` is sent so the client can show a retry button.
enum SSEResponse {
    static func make(chunks: AsyncThrowingStream<SummaryDelta, Error>) -> Response {
        let deltas = AsyncThrowingStream<ExplanationDelta, Error> { continuation in
            let task = Task {
                do {
                    for try await chunk in chunks {
                        continuation.yield(ExplanationDelta(delta: chunk.delta))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
        return make(chunks: deltas)
    }

    /// Shared writer for `/summarize` and `/explain`, which stream the same delta shape.
    static func make(chunks: AsyncThrowingStream<ExplanationDelta, Error>) -> Response {
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

    /// Bridges a stream of raw text into delta chunks, cancelling the upstream when the client disconnects.
    static func deltas(from stream: AsyncThrowingStream<String, Error>) -> AsyncThrowingStream<ExplanationDelta, Error> {
        AsyncThrowingStream<ExplanationDelta, Error> { continuation in
            let task = Task {
                do {
                    for try await delta in stream {
                        continuation.yield(ExplanationDelta(delta: delta))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
