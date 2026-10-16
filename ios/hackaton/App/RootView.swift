import SwiftUI

/// Will show `OnboardingFlow` until `settings.hasOnboarded` is true. For now it goes straight to the tabs.
struct RootView: View {
    var body: some View {
        MainTabView()
    }
}

#Preview {
    let env = AppEnvironment.preview()
    RootView()
        .environment(env.settings)
        .environment(env)
}
