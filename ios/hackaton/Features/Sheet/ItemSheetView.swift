import SharedModels
import SwiftUI

/// The sheet for a tapped pin or bunch, in Apple's full-height sheet. Bunches page left/right with an "n / total" counter.
struct ItemSheetView: View {
    let selection: ItemSelection
    let feed: any FeedServicing
    let paperName: (String?) -> String
    /// Closes the sheet and goes back to the map.
    let close: () -> Void

    @State private var index = 0
    @State private var reading: FeedItem?

    init(selection: ItemSelection, feed: any FeedServicing, paperName: @escaping (String?) -> String, close: @escaping () -> Void) {
        self.selection = selection
        self.feed = feed
        self.paperName = paperName
        self.close = close
    }

    private var isBunch: Bool { selection.items.count > 1 }

    var body: some View {
        TabView(selection: $index) {
            ForEach(Array(selection.items.enumerated()), id: \.element.id) { offset, item in
                card(for: item)
                    .tag(offset)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea(edges: .bottom)
        .safeAreaInset(edge: .top, spacing: 0) {
                if isBunch {
                PageCounter(index: index, count: selection.items.count, color: selection.kind.color)
                    .padding(.top, 14)
                    .padding(.bottom, 2)
            }
        }
        .background(Theme.background)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.background)
        .sensoryFeedback(.selection, trigger: index)
        .fullScreenCover(item: $reading) { item in
            // Back returns to the sheet, on the same page in a bunch so you can keep swiping.
            ArticleReaderView(item: item, feed: feed, paperName: paperName(item.paperId), backTitle: "Tilbake") {
                reading = nil
            }
        }
    }

    @ViewBuilder
    private func card(for item: FeedItem) -> some View {
        switch item.details {
        case .article(let details):
            ArticleCardView(item: item, details: details, paperName: paperName(item.paperId)) {
                reading = item
            }
        case .event(let details):
            EventCardView(item: item, details: details, paperName: paperName(item.paperId))
        case .ad(let details):
            AdCardView(item: item, details: details)
        }
    }
}

/// "2 / 5" with a dot row, so you always know where you are in a bunch.
private struct PageCounter: View {
    let index: Int
    let count: Int
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Text("\(index + 1) / \(count)")
                .font(.system(size: 13, weight: .bold).monospacedDigit())
                .foregroundStyle(Theme.ink)
                .contentTransition(.numericText(value: Double(index)))
            if count <= 12 {
                HStack(spacing: 5) {
                    ForEach(0..<count, id: \.self) { dot in
                        Capsule()
                            .fill(dot == index ? color : Theme.grey)
                            .frame(width: dot == index ? 16 : 6, height: 6)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Theme.surface, in: .capsule)
        .shadow(color: .black.opacity(0.08), radius: 4, y: 1)
        .animation(.snappy(duration: 0.25), value: index)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sak \(index + 1) av \(count)")
    }
}

/// Photo for cards and the reader. It fills a fixed frame, so its size never widens the layout,
/// and its corners are concentric with the sheet or screen around it.
struct HeroImage: View {
    let url: String?
    var height: CGFloat = 220
    var minimumCornerRadius: CGFloat = 18
    /// For a photo sitting on top of a card: rounded top, square bottom against the text.
    var squareBottom = false

    var body: some View {
        Rectangle()
            .fill(Theme.grey)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .overlay {
                AsyncImage(url: url.flatMap(URL.init(string:)), transaction: Transaction(animation: .easeOut(duration: 0.2))) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                    }
                }
            }
            .clipShape(squareBottom
                ? AnyShape(.rect(topLeadingRadius: minimumCornerRadius, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: minimumCornerRadius))
                : AnyShape(ConcentricRectangle(corners: .concentric(minimum: .fixed(minimumCornerRadius)), isUniform: true)))
    }
}

extension String {
    /// "fredag 16. oktober" → "Fredag 16. oktober" (Norwegian keeps month names lower-case).
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}

extension Date {
    /// "torsdag 16. oktober"
    var norwegianDay: String {
        formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "nb_NO")))
    }

    /// "16. okt. 2026, 11:25"
    var norwegianDateTime: String {
        formatted(.dateTime.day().month(.abbreviated).year().hour().minute().locale(Locale(identifier: "nb_NO")))
    }

    /// "20:00"
    var norwegianTime: String {
        formatted(.dateTime.hour().minute().locale(Locale(identifier: "nb_NO")))
    }

    /// Today after 16:00.
    var isTonight: Bool {
        Calendar.current.isDateInToday(self) && Calendar.current.component(.hour, from: self) >= 16
    }
}
