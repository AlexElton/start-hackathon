import Foundation
import Observation

/// Services and stores, created once in the App and passed down with `.environment(...)`.
@Observable
final class AppEnvironment {
    let settings: SettingsStore
    let api: APIClient

    init(settings: SettingsStore, api: APIClient) {
        self.settings = settings
        self.api = api
    }

    static func live() -> AppEnvironment {
        AppEnvironment(settings: SettingsStore(), api: APIClient(baseURL: AppConfig.apiBaseURL))
    }

    /// In-memory settings for SwiftUI previews.
    static func preview() -> AppEnvironment {
        AppEnvironment(
            settings: SettingsStore(defaults: UserDefaults(suiteName: "preview") ?? .standard),
            api: APIClient(baseURL: AppConfig.apiBaseURL)
        )
    }
}
