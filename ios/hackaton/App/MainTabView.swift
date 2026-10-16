import SwiftUI

struct MainTabView: View {
    enum TabID: Hashable {
        case map, summary, settings
    }

    @State private var selection: TabID = .map

    var body: some View {
        TabView(selection: $selection) {
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
