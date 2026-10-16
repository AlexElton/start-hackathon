import Foundation
import Observation

/// Services and stores, created once in the App and passed down with `.environment(...)`.
@Observable
final class AppEnvironment {
    let settings: SettingsStore
    let feed: any FeedServicing
    let location: LocationService
    let images: ImageLoader

    init(settings: SettingsStore, feed: any FeedServicing, location: LocationService, images: ImageLoader) {
        self.settings = settings
        self.feed = feed
        self.location = location
        self.images = images
    }

    static func live() -> AppEnvironment {
        let feed: any FeedServicing
        do {
            feed = try LocalFeedService()
        } catch {
            // The data ships with the app and is checked by the backend tests, so this means a broken build.
            fatalError("Bundled content failed to load: \(error)")
        }
        let settings = SettingsStore()
        if settings.onboardingOnEveryLaunch {
            settings.resetOnboarding()
        }
        return AppEnvironment(
            settings: settings,
            feed: feed,
            location: LocationService(),
            images: ImageLoader()
        )
    }

    /// In-memory settings and mock content for SwiftUI previews.
    static func preview() -> AppEnvironment {
        AppEnvironment(
            settings: SettingsStore(defaults: UserDefaults(suiteName: "preview") ?? .standard),
            feed: MockFeedService(),
            location: LocationService(),
            images: ImageLoader()
        )
    }
}
