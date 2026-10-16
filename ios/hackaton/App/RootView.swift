import SwiftUI

/// Shows the onboarding until it is done, then the tabs. The map plays the globe intro right after.
struct RootView: View {
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        ZStack {
            // The main map opens on the onboarding map's camera. Onboarding stays on top until that map has
            // drawn, then fades away, so the switch can't be seen.
            if settings.hasOnboarded {
                MainTabView()
            }
            if !settings.hasOnboarded || settings.isHandingOff {
                OnboardingFlow()
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.25), value: settings.isHandingOff)
    }
}

#Preview {
    let env = AppEnvironment.preview()
    RootView()
        .environment(env.settings)
        .environment(env)
}
