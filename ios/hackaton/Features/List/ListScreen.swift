import SwiftUI

struct ListScreen: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Ingen saker ennå",
                systemImage: "newspaper",
                description: Text("Listevisningen kommer her.")
            )
            .navigationTitle("Liste")
        }
    }
}

#Preview {
    ListScreen()
}
