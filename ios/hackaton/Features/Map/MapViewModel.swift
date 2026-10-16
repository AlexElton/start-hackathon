import Foundation
import Observation
import OSLog
import SharedModels

/// Owns what the map shows: which layers are on, the loaded items and the zoom slider value.
@Observable
final class MapViewModel {
    /// Default camera, picked on a phone: all of Trondheim from Ila to Lade, slightly tilted, north up.
    static let startCenter = GeoPoint(lat: 63.42719, lon: 10.39500)
    static let startDistance: Double = 15_282
    static let startPitch: Double = 26.5
    static let startHeading: Double = 0

    private(set) var items: [FeedItem] = []
    private(set) var errorMessage: String?

    /// The pin or bunch whose sheet is open.
    var selection: ItemSelection?
    private var paperNames: [String: String] = [:]

    /// The one layer shown at a time. Articles by default.
    private(set) var layer: ItemKind = .article

    /// Slider position, 0 = closest. Follows pinch zoom unless the slider is being dragged.
    var zoomFraction = ZoomScale.fraction(for: MapViewModel.startDistance)
    var isSliderActive = false

    private var fetchTask: Task<Void, Never>?
    private var visibleBox: FeedFilter.BoundingBox?
    private var fetchedBox: FeedFilter.BoundingBox?

    let feed: any FeedServicing

    init(feed: any FeedServicing) {
        self.feed = feed
        Task { await loadPapers() }
    }

    func open(_ items: [FeedItem]) {
        selection = ItemSelection(items: items)
    }

    func paperName(for id: String?) -> String {
        id.flatMap { paperNames[$0] } ?? "Adresseavisen"
    }

    private func loadPapers() async {
        guard let papers = try? await feed.papers() else { return }
        paperNames = Dictionary(papers.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
    }

    func select(_ kind: ItemKind) {
        guard kind != layer else { return }
        layer = kind
        items = items.filter { $0.kind == kind } // Drop the old layer's pins right away.
        fetchedBox = nil
        scheduleFetch(debounce: false)
    }

    func mapZoomChanged(to fraction: Double) {
        guard !isSliderActive else { return }
        zoomFraction = fraction
    }

    /// Called when the map stops moving. Only refetches when the view leaves the area already loaded.
    func visibleRegionChanged(_ box: FeedFilter.BoundingBox) {
        visibleBox = box
        if let fetchedBox, fetchedBox.contains(box) { return }
        scheduleFetch(debounce: true)
    }

    func retry() {
        fetchedBox = nil
        scheduleFetch(debounce: false)
    }

    /// Debounces, cancels the previous request, and fetches 1.5× the visible area so small pans don't refetch.
    private func scheduleFetch(debounce: Bool) {
        fetchTask?.cancel()
        let box = (visibleBox ?? Self.defaultBox).scaled(by: 1.5)
        let filter = FeedFilter(kinds: [layer], bbox: box)
        fetchTask = Task {
            if debounce {
                try? await Task.sleep(for: .milliseconds(300))
            }
            guard !Task.isCancelled else { return }
            do {
                let page = try await feed.feed(filter)
                guard !Task.isCancelled else { return }
                items = page.items
                fetchedBox = box
                errorMessage = nil
            } catch is CancellationError {
            } catch {
                guard !Task.isCancelled else { return }
                Self.logger.error("Feed request failed: \(error)")
                errorMessage = "Fikk ikke hentet innhold"
            }
        }
    }

    private static let logger = Logger(subsystem: "hackaton", category: "Map")

    private static let defaultBox = FeedFilter.BoundingBox(
        minLat: startCenter.lat - 0.1, minLon: startCenter.lon - 0.25,
        maxLat: startCenter.lat + 0.1, maxLon: startCenter.lon + 0.25
    )
}

extension FeedFilter.BoundingBox {
    func contains(_ other: Self) -> Bool {
        minLat <= other.minLat && minLon <= other.minLon && maxLat >= other.maxLat && maxLon >= other.maxLon
    }

    /// The same centre, with each side `factor` times as long.
    func scaled(by factor: Double) -> Self {
        let halfLat = (maxLat - minLat) * factor / 2
        let halfLon = (maxLon - minLon) * factor / 2
        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
        return Self(minLat: centerLat - halfLat, minLon: centerLon - halfLon, maxLat: centerLat + halfLat, maxLon: centerLon + halfLon)
    }
}
