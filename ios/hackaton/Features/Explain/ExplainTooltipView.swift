import SwiftUI

/// The streaming "Forklar" bubble, shown as a popover anchored to the selected text.
/// Grows while the explanation streams; shows a retry button if the request failed.
struct ExplainTooltipView: View {
    let model: ExplainViewModel
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundStyle(Theme.adressaBlue)
                Text("Forklar")
                    .font(Theme.button)
                    .foregroundStyle(Theme.secondaryInk)
                Spacer()
                Button(action: close) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.secondaryInk)
                }
                .buttonStyle(.plain)
            }

            switch model.state {
            case .idle:
                EmptyView()

            case .streaming(let text):
                if text.isEmpty {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Tenker …")
                            .font(Theme.meta)
                            .foregroundStyle(Theme.secondaryInk)
                    }
                } else {
                    Text(text)
                        .font(Theme.serifBody())
                        .foregroundStyle(Theme.ink)
                        .textSelection(.enabled)
                }

            case .failed:
                VStack(alignment: .leading, spacing: 8) {
                    Text("Kunne ikke hente en forklaring.")
                        .font(Theme.meta)
                        .foregroundStyle(Theme.secondaryInk)
                    Button("Prøv igjen") { model.retry() }
                        .font(Theme.button)
                        .buttonStyle(.bordered)
                }
            }
        }
        .padding(12)
        .frame(width: 280, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Theme.grey.opacity(0.4), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
    }
}
