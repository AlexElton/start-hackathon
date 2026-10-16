import SwiftUI

/// Shows the onboarding until it is done, then the tabs. The map plays the globe intro right after.
struct RootView: View {
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        ZStack {
            // Onboarding dives down to the city on its own map while the main map waits underneath on the same
            // camera. Once both have landed and drawn, onboarding fades away; both maps are still, so it's smooth.
            if settings.hasOnboarded {
                MainTabView()
            }
            if !settings.hasOnboarded || settings.isHandingOff {
                OnboardingFlow()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: settings.isHandingOff)
    }
}

#Preview {
    let env = AppEnvironment.preview()
    RootView()
        .environment(env.settings)
        .environment(env)
}
