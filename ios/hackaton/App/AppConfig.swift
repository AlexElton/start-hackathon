import Foundation

enum AppConfig {
    /// Local Vapor backend. Point this at the deployed host before the demo.
    static let apiBaseURL = URL(string: "http://localhost:8080/api/v1")!
}
