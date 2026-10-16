import SwiftUI

@main
struct hackatonApp: App {
    @State private var environment = AppEnvironment.live()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(environment.settings)
                .environment(environment)
        }
    }
}
