import SwiftUI

struct MapScreen: View {
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        MapView(style: settings.mapStyle)
            .ignoresSafeArea()
    }
}

#Preview {
    MapScreen()
        .environment(AppEnvironment.preview().settings)
}
