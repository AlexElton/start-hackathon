import SwiftUI

struct SettingsScreen: View {
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        @Bindable var settings = settings

        NavigationStack {
            Form {
                Section("Kart") {
                    Picker("Kartstil", selection: $settings.mapStyle) {
                        ForEach(MapStyle.allCases) { style in
                            Text(style.title).tag(style)
                        }
                    }
                }

                Section("Intro") {
                    Toggle("Intro ved hver oppstart", isOn: $settings.introOnEveryLaunch)
                }

                Section {
                    Toggle("Onboarding ved hver oppstart", isOn: $settings.onboardingOnEveryLaunch)
                    Button("Spill av intro") {
                        settings.pendingGlobeIntro = true
                    }
                    Button("Start onboarding på nytt") {
                        settings.resetOnboarding()
                    }
                } header: {
                    Text("Demo")
                } footer: {
                    Text("Når bryteren er på, starter appen med en helt ny onboarding hver gang den åpnes.")
                }

                Section {
                    LabeledContent("Versjon", value: Self.appVersion)
                }
            }
            .navigationTitle("Innstillinger")
        }
    }

    private static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–"
    }
}

#Preview {
    SettingsScreen()
        .environment(AppEnvironment.preview().settings)
}
