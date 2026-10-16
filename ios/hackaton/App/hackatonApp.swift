import SwiftUI

@main
struct hackatonApp: App {
    @State private var environment = AppEnvironment.live()

    init() {
        URLCache.shared = URLCache(memoryCapacity: 64 * 1024 * 1024, diskCapacity: 256 * 1024 * 1024)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(environment.settings)
                .environment(environment)
        }
    }
}
