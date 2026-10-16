// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SharedModels",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [
        // API types used by the app and the backend.
        .library(name: "SharedModels", targets: ["SharedModels"]),
        // The content engine and its mock data: loads the JSON, answers feed and article queries.
        // The app runs it on the phone; the Vapor backend serves the same results over HTTP.
        .library(name: "FeedEngine", targets: ["FeedEngine"]),
    ],
    targets: [
        .target(name: "SharedModels"),
        .target(
            name: "FeedEngine",
            dependencies: ["SharedModels"],
            resources: [.copy("Data")]
        ),
    ]
)
