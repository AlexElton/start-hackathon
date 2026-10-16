import SharedModels
import SwiftUI

/// "Les hele saken": the full article, full screen. Back returns to the sheet (in a bunch) or the map.
struct ArticleReaderView: View {
    let item: FeedItem
    let feed: any FeedServicing
    let paperName: String
    var backTitle = "Kart"
    let close: () -> Void

    @State private var state: LoadState<ArticleDetail> = .idle

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Starts right below the status bar and camera cutout, not under them.
                HeroImage(url: item.imageUrl, height: 320, minimumCornerRadius: 24)
                    .padding(.horizontal, 10)
                    .padding(.top, 4)

                VStack(alignment: .leading, spacing: 14) {
                    Kicker(text: section)
                    Text(item.title)
                        .font(Theme.headline(32))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    switch state {
                    case .idle, .loading:
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    case .failed(let message):
                        ContentUnavailableView {
                            Label("Fikk ikke lastet saken", systemImage: "wifi.exclamationmark")
                        } description: {
                            Text(message)
                        } actions: {
                            Button("Prøv igjen") { Task { await load() } }
                        }
                    case .loaded(let article):
                        content(for: article)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .background(Theme.surface)
        .overlay(alignment: .topLeading) {
            Button(action: close) {
                Label(backTitle, systemImage: "chevron.left")
                    .font(.system(size: 15, weight: .bold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .capsule)
            .padding(.leading, 20)
            .padding(.top, 14)
            .accessibilityLabel(backTitle == "Kart" ? "Tilbake til kartet" : "Tilbake")
        }
        .task { await load() }
    }

    private var section: String {
        if case .loaded(let article) = state, let section = article.section { return section }
        return item.location.name ?? item.kind.label
    }

    @ViewBuilder
    private func content(for article: ArticleDetail) -> some View {
        if let lead = article.lead {
            Text(lead)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }

        VStack(alignment: .leading, spacing: 10) {
            SourceBadge(paperName: paperName)
            Group {
                if let author = article.author { Text(author).fontWeight(.semibold) }
                Text("Publisert \(article.publishedAt.norwegianDateTime)")
            }
            .font(Theme.meta)
            .foregroundStyle(Theme.secondaryInk)
        }
        .padding(.vertical, 6)

        Divider()

        VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(article.body.enumerated()), id: \.offset) { _, paragraph in
                if Self.isHeading(paragraph) {
                    Text(paragraph)
                        .font(.system(size: 20, weight: .heavy, design: .serif))
                        .foregroundStyle(Theme.ink)
                        .padding(.top, 8)
                } else {
                    Text(paragraph)
                        .font(Theme.serifBody(18))
                        .foregroundStyle(Theme.ink)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            }
        }
        .padding(.top, 8)

        if let url = URL(string: article.sourceUrl) {
            Link(destination: url) {
                Label("Les saken på adressa.no", systemImage: "arrow.up.right")
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.top, 24)
        }
    }

    /// The body is plain paragraphs; short lines without closing punctuation are the sub-headings.
    private static func isHeading(_ text: String) -> Bool {
        text.count < 60 && !text.contains("\n") && !(text.last.map { ".!?:»\"".contains($0) } ?? false)
    }

    private func load() async {
        guard case .article(let details) = item.details else { return }
        state = .loading
        do {
            state = .loaded(try await feed.article(id: details.articleId))
        } catch {
            state = .failed("Sjekk nettet og prøv igjen.")
        }
    }
}

#Preview {
    ArticleReaderView(item: FeedItem.samples[0], feed: MockFeedService(), paperName: "Adresseavisen", backTitle: "Tilbake") {}
}
