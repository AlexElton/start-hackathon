import SharedModels
import SwiftUI

/// Chips at the top of the map for Saker, Arrangementer and Tilbud. One is on at a time.
/// Brand style: selected is solid Adressablå with white text, the rest white with black text.
struct LayerFilterBar: View {
    let selected: ItemKind
    let select: (ItemKind) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(ItemKind.allCases, id: \.self) { kind in
                let isOn = selected == kind
                Button {
                    select(kind)
                } label: {
                    Text(kind.title)
                        .font(.system(size: 14, weight: .bold))
                        .lineLimit(1)
                        .fixedSize()
                        .foregroundStyle(isOn ? .white : Theme.ink)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 11)
                        .background(isOn ? Theme.adressaBlue : Theme.surface, in: .capsule)
                        .shadow(color: .black.opacity(isOn ? 0.25 : 0.15), radius: 6, y: 2)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .animation(.snappy(duration: 0.2), value: selected)
        .sensoryFeedback(.selection, trigger: selected)
    }
}

#Preview {
    @Previewable @State var selected = ItemKind.article
    LayerFilterBar(selected: selected) { selected = $0 }
        .padding()
        .background(.gray)
}
