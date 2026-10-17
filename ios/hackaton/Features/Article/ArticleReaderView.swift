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
    @State private var dragOffset: CGFloat = 0
    /// Decided at the start of each drag and kept until the finger lifts: true = swiping back, false = scrolling.
    @State private var isSwipingBack: Bool?
    @State private var width: CGFloat = 400
    /// Back only fires once, even if the button and the swipe both trigger it.
    @State private var isClosing = false

    /// Slides the article off to the right, like a navigation pop, then closes it without the default slide-down.
    private func goBack() {
        guard !isClosing else { return }
        isClosing = true
        withAnimation(.easeOut(duration: 0.25)) {
            dragOffset = width
        } completion: {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { close() }
        }
    }

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
        .scrollDisabled(isSwipingBack == true)
        .background(Theme.surface)
        .overlay(alignment: .topLeading) {
            Button(action: goBack) {
                Label(backTitle, systemImage: "chevron.left")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .contentShape(.capsule)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular, in: .capsule)
            // A generous tap area, so a tap that lands a little off still goes back.
            .padding(.leading, 20)
            .padding(.top, 14)
            .padding(.trailing, 20)
            .padding(.bottom, 14)
            .contentShape(.rect)
            .onTapGesture(perform: goBack)
            .accessibilityLabel(backTitle == "Kart" ? "Tilbake til kartet" : "Tilbake")
        }
        .shadow(color: .black.opacity(dragOffset > 0 ? 0.25 : 0), radius: 20)
        .offset(x: dragOffset)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        // The map or sheet underneath shows while the article is swiped away.
        .presentationBackground(.clear)
        // Swipe right to go back. The direction is locked at the start: a sideways swipe moves the
        // article and stops scrolling, an up/down drag only scrolls.
        .simultaneousGesture(
            DragGesture(minimumDistance: 15)
                .onChanged { value in
                    guard !isClosing else { return }
                    if isSwipingBack == nil {
                        isSwipingBack = value.translation.width > 0 && abs(value.translation.width) > abs(value.translation.height) * 1.2
                    }
                    guard isSwipingBack == true else { return }
                    dragOffset = max(0, value.translation.width)
                }
                .onEnded { value in
                    defer { isSwipingBack = nil }
                    guard isSwipingBack == true, !isClosing else { return }
                    if value.translation.width > width * 0.3 || value.predictedEndTranslation.width > width * 0.6 {
                        goBack()
                    } else {
                        withAnimation(.snappy(duration: 0.25)) { dragOffset = 0 }
                    }
                }
        )
        .sensoryFeedback(.impact(weight: .light), trigger: isClosing)
        .task { await load() }
    }

    private var section: String {
        if case .loaded(let article) = state, let section = article.section { return section }
        return item.location?.name ?? item.kind.label
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
