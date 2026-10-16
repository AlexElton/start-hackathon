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

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        mapStyle = defaults.string(forKey: Keys.mapStyle).flatMap(MapStyle.init) ?? .standard
        introOnEveryLaunch = defaults.object(forKey: Keys.introOnEveryLaunch) as? Bool ?? true
        hasOnboarded = defaults.bool(forKey: Keys.hasOnboarded)
    }

    private enum Keys {
        static let mapStyle = "settings.mapStyle"
        static let introOnEveryLaunch = "settings.introOnEveryLaunch"
        static let hasOnboarded = "settings.hasOnboarded"
    }
}
