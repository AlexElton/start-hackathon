import Foundation

enum AppConfig {
    /// Vapor backend, used only by `LiveFeedService`. The app itself runs on bundled content (`LocalFeedService`).
    static let apiBaseURL = URL(string: "http://localhost:8080/api/v1")!
}
