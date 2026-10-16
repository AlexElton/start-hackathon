import SwiftUI
import UIKit

/// Selectable text with a "Forklar" action in the selection menu.
/// Selecting a word or phrase opens a popover that streams the AI explanation,
/// anchored to the text. Closing it cancels the request.
struct ExplainableText: View {
    @Environment(AppEnvironment.self) private var environment

    let text: String
    let font: UIFont
    let color: UIColor
    /// The article title, sent as context so names are resolved correctly.
    let title: String
    let itemId: String

    @State private var model: ExplainViewModel?

    var body: some View {
        SelectableTextView(text: text, font: font, color: color) { term, paragraph in
            let viewModel = ExplainViewModel(service: environment.explain)
            viewModel.explain(term: term, context: paragraph, title: title, itemId: itemId)
            model = viewModel
        }
        .popover(isPresented: Binding(
            get: { model != nil },
            set: { shown in
                if !shown {
                    model?.cancel()
                    model = nil
                }
            }
        )) {
            if let model {
                ExplainTooltipView(model: model) {
                    model.cancel()
                    self.model = nil
                }
                .presentationCompactAdaptation(.popover)
                .presentationBackground(.clear)
            }
        }
    }
}
