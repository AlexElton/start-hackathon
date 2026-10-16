import SwiftUI

/// Capsule chip in the brand style: selected is filled, the rest white with a soft shadow.
struct ChipButton: View {
    let title: String
    var symbol: String?
    let isOn: Bool
    var tint: Color = Theme.adressaBlue
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 13, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .lineLimit(1)
            }
            .foregroundStyle(isOn ? .white : Theme.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isOn ? tint : Theme.surface, in: .capsule)
            .overlay(Capsule().stroke(isOn ? .clear : Theme.grey))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// Lays out children left to right and wraps to new lines, like words in a paragraph.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews, width: proposal.width ?? .infinity)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(subviews, width: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> [Row] {
        var rows = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if !rows[rows.count - 1].indices.isEmpty, rows[rows.count - 1].width + spacing + size.width > width {
                rows.append(Row())
            }
            var row = rows[rows.count - 1]
            row.width += (row.indices.isEmpty ? 0 : spacing) + size.width
            row.height = max(row.height, size.height)
            row.indices.append(index)
            rows[rows.count - 1] = row
        }
        return rows
    }
}

/// Text field with a "Legg til" button, for adding own interests or muted words.
struct AddWordField: View {
    let placeholder: String
    let add: (String) -> Void
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .focused($focused)
                .onSubmit(commit)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Theme.surface, in: .capsule)
                .overlay(Capsule().stroke(Theme.grey))
            Button("Legg til", action: commit)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Theme.adressaBlue, in: .capsule)
                .opacity(text.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)
                .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private func commit() {
        let word = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !word.isEmpty else { return }
        add(word)
        text = ""
    }
}
