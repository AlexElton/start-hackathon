import Foundation
import Observation

/// Which tab is showing, and links into the app (e.g. from the Sammendrag widget).
@Observable
final class AppRouter {
    var tab: MainTabView.TabID = .map
    /// A summary to open in Sammendrag; cleared once shown.
    var digestId: String?

    /// `hackaton://sammendrag/<id>` opens Sammendrag on that summary.
    func open(_ url: URL) {
        guard url.scheme == "hackaton", url.host == "sammendrag" else { return }
        digestId = url.pathComponents.dropFirst().first
        tab = .summary
    }
}
