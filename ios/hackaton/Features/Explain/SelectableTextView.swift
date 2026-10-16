import SwiftUI
import UIKit

/// A selectable, scroll-disabled text view whose selection menu gets a "Forklar" action.
/// Reports the selected term plus the surrounding paragraph, so the AI knows what the
/// word refers to.
struct SelectableTextView: UIViewRepresentable {
    let text: String
    let font: UIFont
    let color: UIColor
    /// Called with the selected term and the paragraph it was selected in.
    let onExplain: (_ term: String, _ paragraph: String) -> Void

    func makeUIView(context: Context) -> UITextView {
        let view = ContentSizingTextView()
        view.isEditable = false
        view.isScrollEnabled = false
        view.backgroundColor = .clear
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        view.font = font
        view.textColor = color
        view.isSelectable = true
        view.delegate = context.coordinator
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        if view.text != text {
            view.text = text
        }
        view.font = font
        view.textColor = color
        context.coordinator.parent = self
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: SelectableTextView

        init(parent: SelectableTextView) {
            self.parent = parent
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            // Keep the menu from re-appearing while typing; not needed for read-only text.
        }

        /// Adds "Forklar" to the selection menu (iOS 16+ edit-menu API).
        func textView(
            _ textView: UITextView,
            editMenuForTextIn range: NSRange,
            suggestedActions: [UIMenuElement]
        ) -> UIMenu? {
            guard let term = trimmedTerm(in: textView, range: range), !term.isEmpty else { return nil }
            let paragraph = surroundingParagraph(in: textView, range: range)

            let explain = UIAction(title: "Forklar", image: UIImage(systemName: "sparkles")) { [weak self] _ in
                self?.parent.onExplain(term, paragraph)
            }
            return UIMenu(title: "", children: [explain] + suggestedActions)
        }

        /// The selection, trimmed of whitespace and punctuation — a word or short phrase.
        private func trimmedTerm(in textView: UITextView, range: NSRange) -> String? {
            guard let uiRange = Range(range, in: textView.text) else { return nil }
            let trimmed = String(textView.text[uiRange])
                .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
            return trimmed.isEmpty ? nil : trimmed
        }

        /// The paragraph containing the selection, used as context for the explanation.
        private func surroundingParagraph(in textView: UITextView, range: NSRange) -> String {
            let full = textView.text as NSString
            let paragraphRange = full.paragraphRange(for: range)
            return full.substring(with: paragraphRange)
        }
    }
}

/// A text view that reports its wrapped content size to SwiftUI. A plain `UITextView`
/// sizes itself to one long line when first measured, which made the article wider
/// than the screen; this one re-measures against the width SwiftUI actually gives it.
private final class ContentSizingTextView: UITextView {
    override var intrinsicContentSize: CGSize {
        let width = bounds.width
        let height = sizeThatFits(CGSize(width: max(width, 1), height: .greatestFiniteMagnitude)).height
        return CGSize(width: width > 0 ? width : UIView.noIntrinsicMetric, height: height)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // The first layout pass starts at width 0; re-measure once the real width is set.
        invalidateIntrinsicContentSize()
    }
}
