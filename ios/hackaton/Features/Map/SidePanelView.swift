import SharedModels
import SwiftUI

/// Panel that slides in from the left edge: articles that cannot be placed on the map.
struct SidePanelView: View {
    let items: [FeedItem]
    let feed: any FeedServicing
    let paperName: (String?) -> String
    let close: () -> Void

    @State private var reading: FeedItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Generelle saker")
                        .font(Theme.headline(24))
                        .foregroundStyle(Theme.ink)
                }
                Spacer()
                Button {
                    close()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.secondaryInk)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Theme.ink.opacity(0.08)))
                }
                .accessibilityLabel("Lukk")
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 16)

            if items.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "map")
                        .font(.system(size: 30))
                        .foregroundStyle(Theme.secondaryInk)
                    Text("Ingen saker uten sted akkurat nå")
                        .font(Theme.meta)
                        .foregroundStyle(Theme.secondaryInk)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 14) {
                        ForEach(items) { item in
                            Button {
                                reading = item
                            } label: {
                                SidePanelCard(item: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.background.ignoresSafeArea())
        .fullScreenCover(item: $reading) { item in
            ArticleReaderView(item: item, feed: feed, paperName: paperName(item.paperId), backTitle: "Kart") {
                reading = nil
            }
        }
    }
}

/// Card in the drawer, matching the article sheet cards: photo, kicker + date row,
/// serif headline, lead.
private struct SidePanelCard: View {
    let item: FeedItem

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HeroImage(url: item.imageUrl, height: 150, minimumCornerRadius: 18, squareBottom: true)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Kicker(text: item.location?.name ?? item.kind.label)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(item.date.norwegianDay)
                        .font(Theme.meta)
                        .foregroundStyle(Theme.secondaryInk)
                        .fixedSize()
                }
                Text(item.title)
                    .font(Theme.headline(21))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if case .article(let details) = item.details, let lead = details.lead {
                    Text(lead)
                        .font(Theme.lead)
                        .foregroundStyle(Theme.secondaryInk)
                        .lineLimit(3)
                }
            }
            .padding(16)
        }
        .background(Theme.surface, in: .rect(cornerRadius: 18))
        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
    }
}
