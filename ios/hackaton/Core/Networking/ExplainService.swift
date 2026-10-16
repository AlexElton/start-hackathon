import Foundation
import SharedModels

/// Streams AI explanations of selected terms from `POST /explain`.
/// The live service parses the backend's SSE stream; the mock yields a canned
/// explanation word by word so previews and offline demos work.
protocol ExplainServicing {
    func explain(_ request: ExplainRequest) async throws -> AsyncThrowingStream<ExplanationDelta, Error>
}

/// Talks to the Vapor backend: POSTs the term + context and yields `{"delta": "…"}` chunks
/// as they arrive, so the tooltip grows while Gemini is still writing.
struct LiveExplainService: ExplainServicing {
    let baseURL: URL
    var session: URLSession = .shared

    func explain(_ request: ExplainRequest) async throws -> AsyncThrowingStream<ExplanationDelta, Error> {
        var httpRequest = URLRequest(url: baseURL.appending(path: API.Path.explain))
        httpRequest.httpMethod = "POST"
        httpRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        httpRequest.httpBody = try JSONEncoder.api.encode(request)

        let (bytes, response) = try await session.bytes(for: httpRequest)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await line in bytes.lines {
                        if line.hasPrefix("event: error") { throw URLError(.cannotDecodeContentData) }
                        guard line.hasPrefix("data: ") else { continue }
                        let payload = line.dropFirst(6)
                        if let delta = try? JSONDecoder.api.decode(ExplanationDelta.self, from: Data(payload.utf8)) {
                            continuation.yield(delta)
                        }
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

/// Canned explanation for previews and offline demos: streams word by word with a small delay,
/// so the tooltip visibly grows like the real thing.
struct MockExplainService: ExplainServicing {
    func explain(_ request: ExplainRequest) async throws -> AsyncThrowingStream<ExplanationDelta, Error> {
        let words = """
            \(request.term) er et begrep fra saken «\(request.title)». \
            Denne forklaringen er en forhåndsskrevet demo, ikke ekte AI.
            """
            .split(separator: " ")
            .map(String.init)

        return AsyncThrowingStream { continuation in
            let task = Task {
                for word in words {
                    try Task.checkCancellation()
                    continuation.yield(ExplanationDelta(delta: word + " "))
                    try? await Task.sleep(for: .milliseconds(90))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
