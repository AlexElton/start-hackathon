import SharedModels
import SwiftUI

struct SettingsScreen: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(SettingsStore.self) private var settings
    @State private var categories: [SharedModels.Category] = []
    @State private var isEditing = false

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

                Section {
                    LabeledContent("Interesser", value: summary(categoryIds: settings.preferredCategories, words: settings.interestWords))
                    LabeledContent("Skjult", value: summary(categoryIds: settings.blockedCategories, words: settings.mutedWords))
                    Button("Endre valgene dine") {
                        isEditing = true
                    }
                } header: {
                    Text("Ditt kart")
                }

                Section {
                    Toggle("Intro ved oppstart", isOn: $settings.introOnEveryLaunch)
                    Toggle("Onboarding ved oppstart", isOn: $settings.onboardingOnEveryLaunch)
                } header: {
                    Label("Utviklerinnstillinger", systemImage: "hammer")
                } footer: {
                    Text("Kun for testing og demo. Ikke en del av appen for vanlige brukere.")
                }
            }
            .navigationTitle("Innstillinger")
            // Steps 1 and 2 only, opened with the current choices; saving comes straight back here.
            .fullScreenCover(isPresented: $isEditing) {
                OnboardingFlow { isEditing = false }
            }
            .task {
                categories = (try? await environment.feed.categories()) ?? []
            }
        }
    }

    private func summary(categoryIds: [String], words: [String]) -> String {
        let names = categoryIds.compactMap { id in categories.first { $0.id == id }?.name } + words
        guard let first = names.first else { return "Ingen" }
        return names.count == 1 ? first : "\(first) +\(names.count - 1)"
    }
}

#Preview {
    let env = AppEnvironment.preview()
    SettingsScreen()
        .environment(env.settings)
        .environment(env)
}
