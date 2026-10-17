import SwiftUI

struct MainTabView: View {
    enum TabID: Hashable {
        case map, summary, settings
    }

    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        @Bindable var router = environment.router
        TabView(selection: $router.tab) {
            Tab("Kart", systemImage: "map", value: .map) {
                MapScreen()
            }
            Tab("Sammendrag", systemImage: "text.alignleft", value: .summary) {
                SummaryScreen()
            }
            Tab("Innstillinger", systemImage: "gearshape", value: .settings) {
                SettingsScreen()
            }
        }
    }
}

#Preview {
    let env = AppEnvironment.preview()
    MainTabView()
        .environment(env.settings)
        .environment(env)
}
