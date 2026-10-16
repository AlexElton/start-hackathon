import SwiftUI

struct MainTabView: View {
    enum TabID: Hashable {
        case map, list, settings
    }

    @State private var selection: TabID = .map

    var body: some View {
        TabView(selection: $selection) {
            Tab("Kart", systemImage: "map", value: .map) {
                MapScreen()
            }
            Tab("Liste", systemImage: "list.bullet", value: .list) {
                ListScreen()
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
