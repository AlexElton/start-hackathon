import Foundation
import Observation

enum MapStyle: String, CaseIterable, Identifiable {
    case standard
    case hybrid
    case satellite

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard: "Standard"
        case .hybrid: "Satellitt med navn"
        case .satellite: "3D-satellitt"
        }
    }
}

/// User settings persisted in UserDefaults. Each property writes through on change.
@Observable
final class SettingsStore {
    private let defaults: UserDefaults

    var mapStyle: MapStyle {
        didSet { defaults.set(mapStyle.rawValue, forKey: Keys.mapStyle) }
    }

    var introOnEveryLaunch: Bool {
        didSet { defaults.set(introOnEveryLaunch, forKey: Keys.introOnEveryLaunch) }
    }

    var hasOnboarded: Bool {
        didSet { defaults.set(hasOnboarded, forKey: Keys.hasOnboarded) }
    }

    /// Demo helper: start a fresh onboarding every time the app launches.
    var onboardingOnEveryLaunch: Bool {
        didSet { defaults.set(onboardingOnEveryLaunch, forKey: Keys.onboardingOnEveryLaunch) }
    }

    /// The first intro (Norway → your city) plays once after onboarding, and again when replayed from Innstillinger.
    var pendingGlobeIntro: Bool {
        didSet { defaults.set(pendingGlobeIntro, forKey: Keys.pendingGlobeIntro) }
    }

    /// Where the onboarding map was when the user finished, so the first intro starts from the same view.
    /// Lives only for this app session.
    var introStartCamera: CameraSpec?

    /// True from "Kom i gang" until the main map has drawn its first frame: onboarding stays on top meanwhile.
    var isHandingOff = false

    // MARK: Onboarding choices

    /// Categories the user wants to read (boosts relevance).
    var preferredCategories: [String] {
        didSet { defaults.set(preferredCategories, forKey: Keys.preferredCategories) }
    }

    /// Own interests typed in during onboarding.
    var interestWords: [String] {
        didSet { defaults.set(interestWords, forKey: Keys.interestWords) }
    }

    /// Categories the user never wants to see.
    var blockedCategories: [String] {
        didSet { defaults.set(blockedCategories, forKey: Keys.blockedCategories) }
    }

    /// Words that hide an item when they appear in its title or tags.
    var mutedWords: [String] {
        didSet { defaults.set(mutedWords, forKey: Keys.mutedWords) }
    }

    /// Fylke picked on the region map, e.g. "trondelag".
    var regionId: String? {
        didSet { defaults.set(regionId, forKey: Keys.regionId) }
    }

    /// The regional paper plus the local papers the user kept.
    var paperIds: [String] {
        didSet { defaults.set(paperIds, forKey: Keys.paperIds) }
    }

    var startMode: StartMode {
        didSet { defaults.set(startMode.rawValue, forKey: Keys.startMode) }
    }

    enum StartMode: String {
        /// Start over the regional paper's city.
        case paper
        /// Start at the user's own position.
        case position
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        mapStyle = defaults.string(forKey: Keys.mapStyle).flatMap(MapStyle.init) ?? .standard
        introOnEveryLaunch = defaults.object(forKey: Keys.introOnEveryLaunch) as? Bool ?? true
        hasOnboarded = defaults.bool(forKey: Keys.hasOnboarded)
        onboardingOnEveryLaunch = defaults.bool(forKey: Keys.onboardingOnEveryLaunch)
        pendingGlobeIntro = defaults.bool(forKey: Keys.pendingGlobeIntro)
        preferredCategories = defaults.stringArray(forKey: Keys.preferredCategories) ?? []
        interestWords = defaults.stringArray(forKey: Keys.interestWords) ?? []
        blockedCategories = defaults.stringArray(forKey: Keys.blockedCategories) ?? []
        mutedWords = defaults.stringArray(forKey: Keys.mutedWords) ?? []
        regionId = defaults.string(forKey: Keys.regionId)
        paperIds = defaults.stringArray(forKey: Keys.paperIds) ?? []
        startMode = defaults.string(forKey: Keys.startMode).flatMap(StartMode.init) ?? .paper
    }

    /// Clears everything chosen in onboarding, so it starts fresh.
    func resetOnboarding() {
        hasOnboarded = false
        preferredCategories = []
        interestWords = []
        blockedCategories = []
        mutedWords = []
        regionId = nil
        paperIds = []
        startMode = .paper
        introStartCamera = nil
    }

    private enum Keys {
        static let mapStyle = "settings.mapStyle"
        static let introOnEveryLaunch = "settings.introOnEveryLaunch"
        static let hasOnboarded = "settings.hasOnboarded"
        static let onboardingOnEveryLaunch = "settings.onboardingOnEveryLaunch"
        static let pendingGlobeIntro = "settings.pendingGlobeIntro"
        static let preferredCategories = "settings.preferredCategories"
        static let interestWords = "settings.interestWords"
        static let blockedCategories = "settings.blockedCategories"
        static let mutedWords = "settings.mutedWords"
        static let regionId = "settings.regionId"
        static let paperIds = "settings.paperIds"
        static let startMode = "settings.startMode"
    }
}
