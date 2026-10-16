import Foundation
import Observation
import SharedModels

/// Drives one "Forklar" tooltip: starts the stream when a term is selected,
/// appends deltas as they arrive, and cancels the request when the tooltip closes.
@MainActor
@Observable
final class ExplainViewModel {
    enum State {
        case idle
        case streaming(text: String)
        case failed(term: String, retryable: Bool)
    }

    private(set) var state: State = .idle

    private let service: any ExplainServicing
    private var task: Task<Void, Never>?

    init(service: any ExplainServicing) {
        self.service = service
    }

    /// The explanation text so far, for the tooltip body.
    var text: String {
        if case .streaming(let text) = state { return text }
        return ""
    }

    var isStreaming: Bool {
        if case .streaming = state { return true }
        return false
    }

    /// Starts streaming an explanation for the term. Any running stream is cancelled first.
    func explain(term: String, context: String, title: String, itemId: String) {
        cancel()
        lastContext = context
        lastTitle = title
        lastItemId = itemId
        state = .streaming(text: "")
        task = Task { [service] in
            let request = ExplainRequest(term: term, context: context, title: title, itemId: itemId)
            do {
                let stream = try await service.explain(request)
                var text = ""
                for try await delta in stream {
                    text += delta.delta
                    self.state = .streaming(text: text)
                }
                // Keep the finished text on screen; the tooltip stays until dismissed.
            } catch is CancellationError {
                // Tooltip closed; nothing to show.
            } catch {
                guard !Task.isCancelled else { return }
                self.state = .failed(term: term, retryable: true)
            }
        }
    }

    /// Retries the last term after a failure.
    func retry() {
        guard case .failed(let term, _) = state else { return }
        explain(term: term, context: lastContext, title: lastTitle, itemId: lastItemId)
    }

    /// Cancels the running request and resets the tooltip. Called when the tooltip closes.
    func cancel() {
        task?.cancel()
        task = nil
        state = .idle
    }

    // Context of the last request, kept for retry.
    private var lastContext = ""
    private var lastTitle = ""
    private var lastItemId = ""
}
