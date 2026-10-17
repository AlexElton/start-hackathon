import Foundation
import MapKit
import Observation
import SharedModels

/// Holds the onboarding draft and saves it to `SettingsStore` when the user finishes.
@Observable
final class OnboardingViewModel {
    enum Step: Int, CaseIterable {
        case interests, blacklist, region

        var number: Int { rawValue + 1 }
    }

    var step: Step = .interests
    /// Set by "Kom i gang" on step 3: the white around Norway fades out, then onboarding finishes.
    private(set) var isFadingOut = false
    private var pendingSettings: SettingsStore?
    /// After the fade: where the onboarding map dives to. The main map opens there underneath.
    private(set) var diveTarget: CameraSpec?
    private var location: LocationService?

    private(set) var categories: [SharedModels.Category] = []
    private(set) var papers: [Paper] = []
    private(set) var regions: [RegionShape] = []
    /// Everything outside Norway, covered in white.
    private(set) var cover: MKPolygon?
    /// Lines where two selectable fylker meet.
    private(set) var borders: [MKPolyline] = []
    /// The region map's camera, handed to the first intro so it starts from the same view.
    var regionCamera: CameraSpec?

    // Step 1
    var preferred: Set<String> = []
    var interestWords: [String] = []
    // Step 2
    var blocked: Set<String> = []
    var mutedWords: [String] = []
    // Step 3: only fylker with a Polaris paper can be picked. Skipping starts the map at your position.
    var selectedRegionId: String? {
        didSet { if selectedRegionId != oldValue { prefetchTarget() } }
    }
    private var usePosition = false

    private let feed: any FeedServicing
    private let mapStyle: MapStyle
    private var prefetch: Task<Void, Never>?

    /// Opened from Innstillinger: only the first two steps, saved straight back without the map and intro.
    let isEditing: Bool

    var steps: [Step] { isEditing ? [.interests, .blacklist] : Step.allCases }

    init(feed: any FeedServicing, settings: SettingsStore, isEditing: Bool = false) {
        self.feed = feed
        self.isEditing = isEditing
        mapStyle = settings.mapStyle
        // Start from earlier choices when onboarding is shown again from Innstillinger.
        preferred = Set(settings.preferredCategories)
        interestWords = settings.interestWords
        blocked = Set(settings.blockedCategories)
        mutedWords = settings.mutedWords
        selectedRegionId = settings.regionId
    }

    func load() async {
        categories = (try? await feed.categories()) ?? []
        papers = (try? await feed.papers()) ?? []
        if let data = try? await feed.regions() {
            regions = (try? RegionShape.parse(data)) ?? []
        }
        if let data = try? await feed.norwayOutline() {
            let geometry = ((try? MKGeoJSONDecoder().decode(data)) ?? []).compactMap { ($0 as? MKGeoJSONFeature)?.geometry.first }
            let norway = geometry.compactMap { $0 as? MKMultiPolygon }.flatMap(\.polygons)
            borders = geometry.compactMap { $0 as? MKMultiPolyline }.flatMap(\.polylines)
            let corners = [
                CLLocationCoordinate2D(latitude: 40, longitude: -30),
                CLLocationCoordinate2D(latitude: 84, longitude: -30),
                CLLocationCoordinate2D(latitude: 84, longitude: 60),
                CLLocationCoordinate2D(latitude: 40, longitude: 60),
            ]
            cover = norway.isEmpty ? nil : MKPolygon(coordinates: corners, count: corners.count, interiorPolygons: norway)
        }
    }

    /// Starts loading map tiles for where the intro will land as soon as a fylke is picked,
    /// so the zoom after "Kom i gang" starts right away and doesn't outrun the tiles.
    private func prefetchTarget() {
        prefetch?.cancel()
        guard selectedRegionId != nil else { return }
        let target = IntroCameras.target(regionId: selectedRegionId, papers: papers, regions: regions)
        let style = mapStyle
        prefetch = Task { await TilePrefetcher.warm(along: target, style: style, timeout: .seconds(4)) }
    }

    var selectedRegion: RegionShape? {
        regions.first { $0.id == selectedRegionId }
    }

    var regionalPaper: Paper? {
        guard let id = selectedRegion?.regionalPaperId else { return nil }
        return papers.first { $0.id == id }
    }

    private var localPapers: [Paper] {
        guard let regionId = selectedRegionId else { return [] }
        return papers.filter { $0.regionId == regionId && $0.level == .local }
    }

    /// Categories left for the blacklist: the ones the user did not pick as interests,
    /// with the ones people most often hide first.
    var blockableCategories: [SharedModels.Category] {
        let first = ["krim", "politikk", "sport", "naeringsliv"]
        let left = categories.filter { !preferred.contains($0.id) }
        return first.compactMap { id in left.first { $0.id == id } } + left.filter { !first.contains($0.id) }
    }

    var canContinue: Bool {
        switch step {
        case .interests: !preferred.isEmpty || !interestWords.isEmpty
        case .blacklist: true
        case .region: selectedRegionId != nil
        }
    }

    /// "Hopp over": go to the next step without choosing. On the last step: finish and start at your position.
    func skip(settings: SettingsStore, location: LocationService) {
        self.location = location
        switch step {
        case .interests: step = .blacklist
        case .blacklist: step = .region
        case .region:
            selectedRegionId = nil
            usePosition = true
            location.requestPermission()
            beginFinish(settings: settings)
        }
    }

    func next(settings: SettingsStore) {
        if let next = Step(rawValue: step.rawValue + 1) {
            step = next
        } else {
            beginFinish(settings: settings)
        }
    }

    /// Fades the white around Norway first; the map view calls `fadeFinished()` when it is gone.
    private func beginFinish(settings: SettingsStore) {
        guard !isFadingOut else { return }
        pendingSettings = settings
        isFadingOut = true
    }

    func fadeFinished() {
        prefetch?.cancel() // Never let tile warm-up compete with the dive for the GPU.
        guard let settings = pendingSettings else { return }
        pendingSettings = nil
        finish(into: settings)
        // Dive right away on this very map: it already shows the right picture, so there's no pause.
        diveTarget = IntroCameras.target(settings: settings, papers: papers, regions: regions, location: location ?? LocationService())
    }

    /// The dive has landed. Hand over once the main map underneath has drawn the same view.
    func diveLanded(settings: SettingsStore) {
        Task {
            for _ in 0..<60 where !settings.mainMapRendered {
                try? await Task.sleep(for: .milliseconds(50))
            }
            settings.isHandingOff = false
        }
    }

    func back() {
        step = Step(rawValue: step.rawValue - 1) ?? .interests
    }

    func togglePreferred(_ id: String) {
        if preferred.remove(id) == nil {
            preferred.insert(id)
            blocked.remove(id)
        }
    }

    func toggleBlocked(_ id: String) {
        if blocked.remove(id) == nil { blocked.insert(id) }
    }

    func addInterest(_ word: String) {
        guard !interestWords.contains(where: { $0.caseInsensitiveCompare(word) == .orderedSame }) else { return }
        interestWords.append(word)
    }

    func toggleInterest(_ word: String) {
        if interestWords.contains(where: { $0.caseInsensitiveCompare(word) == .orderedSame }) {
            interestWords.removeAll { $0.caseInsensitiveCompare(word) == .orderedSame }
        } else {
            interestWords.append(word)
        }
    }

    func toggleMuted(_ word: String) {
        if mutedWords.contains(where: { $0.caseInsensitiveCompare(word) == .orderedSame }) {
            mutedWords.removeAll { $0.caseInsensitiveCompare(word) == .orderedSame }
        } else {
            mutedWords.append(word)
        }
    }

    /// Typed-in words that aren't one of the suggestions (suggestions show as chips among the categories).
    var ownInterestWords: [String] { interestWords.filter { !Self.contains($0, in: Self.interestSuggestions) } }
    var ownMutedWords: [String] { mutedWords.filter { !Self.contains($0, in: Self.mutedSuggestions) } }

    static func contains(_ word: String, in words: [String]) -> Bool {
        words.contains { $0.caseInsensitiveCompare(word) == .orderedSame }
    }

    /// Students, Trondheim and a bit of everything; shown after "Vis flere forslag".
    static let interestSuggestions = [
        "NTNU", "Samfundet", "UKA", "ISFiT", "Studentbolig", "Fadderuke", "Deltidsjobb",
        "Rosenborg", "Olavsfestdagene", "Bymarka", "Solsiden", "Bakklandet", "Trondheim Kino", "Kollektivtrafikk", "Trøndersk mat",
        "Festival", "Konsert", "Loppemarked", "Gaming", "Klatring", "Ski", "Bærekraft", "Hund",
    ]

    /// The first ones are shown right away on step 2; the rest after "Vis flere forslag".
    static let popularMuted = ["Kjendiser", "Kongehuset", "Reality-TV", "Ulykker"]
    static let mutedSuggestions = popularMuted + [
        "Influensere", "Sladder", "Horoskop", "Dødsfall", "Krig", "Voldssaker", "Rettssaker",
        "Valgkamp", "Bompenger", "Pengespill", "Børs", "Eiendomspriser", "Fotball",
    ]

    func addMuted(_ word: String) {
        guard !mutedWords.contains(where: { $0.caseInsensitiveCompare(word) == .orderedSame }) else { return }
        mutedWords.append(word)
    }

    /// Saves the draft. The map then plays the globe intro once.
    func finish(into settings: SettingsStore) {
        saveChoices(into: settings)
        settings.regionId = usePosition ? nil : selectedRegionId
        settings.paperIds = usePosition ? [] : [regionalPaper?.id].compactMap { $0 } + localPapers.map(\.id)
        settings.startMode = usePosition ? .position : .paper
        settings.introStartCamera = regionCamera
        settings.pendingGlobeIntro = true
        // Keep this screen on top until the main map has drawn the same view underneath.
        settings.isHandingOff = true
        settings.hasOnboarded = true
    }

    /// Steps 1 and 2: what to read and what to hide.
    func saveChoices(into settings: SettingsStore) {
        settings.preferredCategories = categories.map(\.id).filter(preferred.contains)
        settings.interestWords = interestWords
        settings.blockedCategories = categories.map(\.id).filter(blocked.contains)
        settings.mutedWords = mutedWords
    }
}
