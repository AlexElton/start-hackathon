import CoreLocation
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
    static let startPitch: Double = 34
    static let startHeading: Double = 0

    private(set) var items: [FeedItem] = []
    /// Articles that cannot be placed on the map; shown in the side panel.
    private(set) var unplacedItems: [FeedItem] = []
    private(set) var errorMessage: String?

    /// The pin or bunch whose sheet is open.
    var selection: ItemSelection?
    private var prefetchedImages = Set<URL>()
    private var paperNames: [String: String] = [:]

    /// The one layer shown at a time. Articles by default.
    private(set) var layer: ItemKind = .article

    /// Slider position, 0 = closest. Follows pinch zoom unless the slider is being dragged.
    var zoomFraction = ZoomScale.fraction(for: MapViewModel.startDistance)
    var isSliderActive = false

    private var fetchTask: Task<Void, Never>?
    private var unplacedTask: Task<Void, Never>?
    private var visibleBox: FeedFilter.BoundingBox?
    private var fetchedBox: FeedFilter.BoundingBox?

    // MARK: Start camera and intros

    /// False until the start camera is known; the map is created only then.
    private(set) var isReady = false
    /// The camera the map is created with.
    private(set) var initialCamera = CameraSpec(
        center: .init(latitude: startCenter.lat, longitude: startCenter.lon),
        distance: startDistance, pitch: startPitch, heading: startHeading
    )
    /// Where every intro ends.
    private(set) var target = CameraSpec(
        center: .init(latitude: startCenter.lat, longitude: startCenter.lon),
        distance: startDistance, pitch: startPitch, heading: startHeading
    )
    /// A camera move for the map to make once.
    private(set) var cameraCommand: CameraCommand?
    /// True while an intro flight runs; chips and slider stay hidden until it lands.
    private(set) var isIntroPlaying = false
    /// True while the camera flies: pins wait until it lands, so they don't pop in and load photos mid-dive.
    private(set) var isFlying = false
    /// Intro flight still to start once the map is on screen.
    private var pendingIntro: (duration: Double, hidesChrome: Bool)?
    /// Resumed when the map has drawn its first frame.
    private var hasRendered = false
    private var renderWaiters: [CheckedContinuation<Void, Never>] = []

    // MARK: Personal filters from onboarding

    private var excluded: Set<String> = []
    private var muted: [String] = []
    private var preferred: Set<String> = []

    let feed: any FeedServicing

    init(feed: any FeedServicing) {
        self.feed = feed
    }

    /// Decides the start camera and which intro to play, then lets the map appear.
    /// Right after onboarding: from where the onboarding map ended, down to your city.
    /// Later launches: a quick dive from Europe, if switched on in Innstillinger.
    func prepare(settings: SettingsStore, location: LocationService, reduceMotion: Bool) async {
        defer { isFlying = pendingIntro != nil }
        let papers = (try? await feed.papers()) ?? []
        paperNames = Dictionary(papers.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        let regions = ((try? await feed.regions()).flatMap { try? RegionShape.parse($0) }) ?? []
        applyPreferences(from: settings)

        // Give a first location fix up to about a second when the user starts at their position.
        if settings.startMode == .position, location.lastCoordinate == nil {
            try? await Task.sleep(for: .seconds(1))
        }
        target = IntroCameras.target(settings: settings, papers: papers, regions: regions, location: location)

        if settings.pendingGlobeIntro {
            // Right after onboarding the dive happens on the onboarding map; this map waits underneath on the
            // city it lands on, ready to take over.
            settings.pendingGlobeIntro = false
            initialCamera = target
        } else if settings.introOnEveryLaunch, !reduceMotion {
            initialCamera = IntroCameras.europe(over: target)
            pendingIntro = (duration: 2.0, hidesChrome: false)
        } else {
            initialCamera = target
        }
        isIntroPlaying = pendingIntro?.hidesChrome ?? false
        zoomFraction = ZoomScale.fraction(for: initialCamera.distance)
        isReady = true
    }

    func mapRendered() {
        hasRendered = true
        renderWaiters.forEach { $0.resume() }
        renderWaiters = []
    }

    private func waitForFirstRender() async {
        guard !hasRendered else { return }
        await withCheckedContinuation { renderWaiters.append($0) }
    }

    /// Called once the map is on screen. Right after onboarding: wait until the map has drawn the same view
    /// the onboarding showed, let onboarding fade away, then dive. Later launches: warm the tiles and dive.
    func playIntroIfNeeded(style: MapStyle, settings: SettingsStore) async {
        guard let intro = pendingIntro else { return }
        pendingIntro = nil
        let cinematic = intro.hidesChrome // Only the replay from Innstillinger.
        await TilePrefetcher.warm(along: target, style: style, timeout: .milliseconds(cinematic ? 600 : 900))
        isFlying = true
        cameraCommand = CameraCommand(camera: target, duration: intro.duration, cinematic: cinematic)
        try? await Task.sleep(for: .seconds(intro.duration * 0.85))
        isIntroPlaying = false
        try? await Task.sleep(for: .seconds(intro.duration * 0.15))
        isFlying = false
    }

    /// Replays the first intro (from Innstillinger): jump out to all of Norway, then dive in again.
    func replayIntro(style: MapStyle, settings: SettingsStore) async {
        isIntroPlaying = true
        cameraCommand = CameraCommand(camera: IntroCameras.norway)
        pendingIntro = (duration: 3.8, hidesChrome: true)
        await playIntroIfNeeded(style: style, settings: settings)
    }

    /// Downloads the photos for the loaded pins in the background, so a sheet opens with its picture ready.
    private func prefetchImages(for items: [FeedItem]) {
        let urls = items.compactMap { $0.imageUrl.flatMap(URL.init(string:)) }.filter { prefetchedImages.insert($0).inserted }
        guard !urls.isEmpty else { return }
        Task.detached(priority: .utility) {
            for url in urls {
                _ = try? await URLSession.shared.data(from: url)
            }
        }
    }

    /// Blacklist and interests from onboarding: hidden categories and words, and categories that rank first.
    func applyPreferences(from settings: SettingsStore) {
        let newExcluded = Set(settings.blockedCategories)
        let newMuted = (settings.mutedWords + []).map { $0.lowercased() }
        let newPreferred = Set(settings.preferredCategories)
        guard newExcluded != excluded || newMuted != muted || newPreferred != preferred else { return }
        excluded = newExcluded
        muted = newMuted
        preferred = newPreferred
        fetchedBox = nil
        if isReady { scheduleFetch(debounce: false) }
    }

    func open(_ items: [FeedItem]) {
        guard selection == nil else { return } // A tap and MapKit's own selection can both arrive.
        selection = ItemSelection(items: items)
    }

    func paperName(for id: String?) -> String {
        id.flatMap { paperNames[$0] } ?? "Adresseavisen"
    }

    func select(_ kind: ItemKind) {
        guard kind != layer else { return }
        layer = kind
        items = items.filter { $0.kind == kind } // Drop the old layer's pins right away.
        unplacedItems = []
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
        let filter = FeedFilter(kinds: [layer], exclude: excluded, mute: muted, bbox: box, prefer: preferred)
        fetchUnplacedItems()
        fetchTask = Task {
            if debounce {
                try? await Task.sleep(for: .milliseconds(300))
            }
            guard !Task.isCancelled else { return }
            do {
                let page = try await feed.feed(filter)
                guard !Task.isCancelled else { return }
                items = page.items
                prefetchImages(for: page.items)
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

    /// Fetches the current layer without a bbox and keeps only the items without a place.
    private func fetchUnplacedItems() {
        unplacedTask?.cancel()
        let filter = FeedFilter(kinds: [layer], exclude: excluded, mute: muted, prefer: preferred)
        unplacedTask = Task {
            do {
                let page = try await feed.feed(filter)
                guard !Task.isCancelled else { return }
                unplacedItems = page.items.filter { $0.location == nil }
            } catch is CancellationError {
            } catch {
                Self.logger.error("Unplaced feed request failed: \(error)")
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
