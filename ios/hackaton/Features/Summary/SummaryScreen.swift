import SharedModels
import SwiftUI

/// "Sammendrag": short written summaries. Pick one in the row on top, or swipe between them.
struct SummaryScreen: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var model: SummaryViewModel?
    @State private var reading: FeedItem?
    @State private var opened: ItemSelection?

    var body: some View {
        VStack(spacing: 0) {
            if let model {
                content(model)
            } else {
                Spacer()
            }
        }
        .background(Theme.background)
        .task {
            if model == nil { model = SummaryViewModel(feed: environment.feed) }
            await model?.load(settings: environment.settings)
        }
        .fullScreenCover(item: $reading) { item in
            ArticleReaderView(item: item, feed: environment.feed, paperName: model?.paperName(for: item.paperId) ?? "Adresseavisen", backTitle: "Sammendrag") {
                reading = nil
            }
        }
        .sheet(item: $opened) { selection in
            ItemSheetView(selection: selection, feed: environment.feed, paperName: { model?.paperName(for: $0) ?? "Adresseavisen" }) {
                opened = nil
            }
        }
    }

    @ViewBuilder
    private func content(_ model: SummaryViewModel) -> some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: 4) {
            Kicker(text: Date.now.norwegianDay)
            Text("Sammendrag")
                .font(Theme.headline(34))
                .foregroundStyle(Theme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 8)

        switch model.state {
        case .idle, .loading:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            ContentUnavailableView(message, systemImage: "wifi.exclamationmark", description: Text("Prøv igjen om litt."))
        case .loaded:
            DigestPicker(digests: model.digests, selectedId: $model.selectedId)
                .padding(.vertical, 12)

            TabView(selection: $model.selectedId) {
                ForEach(model.digests) { digest in
                    ScrollView {
                        DigestView(
                            digest: digest,
                            items: model.items(for: digest),
                            article: model.article(for:),
                            read: { reading = $0 },
                            open: { opened = ItemSelection(items: [$0]) }
                        )
                    }
                    .scrollIndicators(.hidden)
                    .refreshable { await model.load(settings: environment.settings) }
                    .tag(Optional(digest.id))
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .sensoryFeedback(.selection, trigger: model.selectedId)
        }
    }
}

/// Row of chips, one per digest, in each digest's colour. Scrolls to keep the selected one visible.
private struct DigestPicker: View {
    let digests: [Digest]
    @Binding var selectedId: String?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(digests) { digest in
                        ChipButton(title: digest.title, symbol: digest.symbol, isOn: digest.id == selectedId, tint: Color(hex: digest.color)) {
                            withAnimation(.snappy) { selectedId = digest.id }
                        }
                        .id(digest.id)
                    }
                }
                .padding(.horizontal, 20)
            }
            .scrollIndicators(.hidden)
            .onChange(of: selectedId) { _, id in
                withAnimation(.snappy) { proxy.scrollTo(id, anchor: .center) }
            }
        }
    }
}

/// One summary: photo with the headline, a short intro, numbered points that open their article,
/// and the events and deals that go with it.
private struct DigestView: View {
    let digest: Digest
    let items: [FeedItem]
    let article: (String?) -> FeedItem?
    let read: (FeedItem) -> Void
    let open: (FeedItem) -> Void

    private var accent: Color { Color(hex: digest.color) }

    private var kicker: String {
        switch digest.scope {
        case .day: return "I dag · \(Date.now.norwegianDay)"
        case .week: return "Uke \(Calendar(identifier: .iso8601).component(.weekOfYear, from: .now))"
        case .category, .place: return digest.kicker ?? digest.title
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            hero
            Text(digest.intro)
                .font(Theme.serifBody(19))
                .foregroundStyle(Theme.ink)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 20)

            points

            if !items.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle(text: digest.scope == .day ? "I kveld og i dag" : "Med på lista", color: accent)
                        .padding(.horizontal, 20)
                    ScrollView(.horizontal) {
                        HStack(spacing: 12) {
                            ForEach(items) { item in
                                Button { open(item) } label: { SmallItemCard(item: item) }
                                    .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .scrollIndicators(.hidden)
                }
            }

            HStack {
                SourceBadge(paperName: "Adresseavisen")
                Spacer()
                Text("Basert på \(digest.points.compactMap(\.articleId).uniqueCount) saker")
                    .font(Theme.meta)
                    .foregroundStyle(Theme.secondaryInk)
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 32)
    }

    private var hero: some View {
        HeroImage(url: digest.imageUrl, height: 300, minimumCornerRadius: 24)
            .overlay {
                LinearGradient(colors: [.clear, .black.opacity(0.15), .black.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                    .clipShape(ConcentricRectangle(corners: .concentric(minimum: .fixed(24)), isUniform: true))
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(kicker.uppercased())
                        .font(.system(size: 12, weight: .heavy))
                        .tracking(0.8)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(accent, in: .capsule)
                    Text(digest.headline)
                        .font(Theme.headline(28))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    Label("\(digest.readMinutes) min lesing · \(digest.points.count) punkter", systemImage: "clock")
                        .font(Theme.meta)
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(20)
            }
            .padding(.horizontal, 16)
    }

    private var points: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(digest.points.enumerated()), id: \.offset) { index, point in
                if index > 0 {
                    Divider().padding(.leading, 62)
                }
                HStack(alignment: .top, spacing: 14) {
                    Text("\(index + 1)")
                        .font(.system(size: 17, weight: .black, design: .serif))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(accent, in: .circle)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(point.title)
                            .font(.system(size: 18, weight: .heavy, design: .serif))
                            .foregroundStyle(Theme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(point.text)
                            .font(Theme.serifBody(16))
                            .foregroundStyle(Theme.secondaryInk)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                        if let item = article(point.articleId) {
                            Button { read(item) } label: {
                                Label("Les saken", systemImage: "arrow.right")
                                    .labelStyle(TrailingIconLabelStyle())
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(accent)
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 2)
                        }
                    }
                }
                .padding(16)
            }
        }
        .background(Theme.surface, in: .rect(cornerRadius: 22))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        .padding(.horizontal, 16)
    }
}

private struct SectionTitle: View {
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Capsule().fill(color).frame(width: 4, height: 18)
            Text(text)
                .font(.system(size: 20, weight: .heavy, design: .serif))
                .foregroundStyle(Theme.ink)
        }
    }
}

/// Compact card for events and deals in the horizontal rows.
private struct SmallItemCard: View {
    let item: FeedItem

    private var subtitle: String {
        switch item.details {
        case .event(let event): "\(event.startsAt.norwegianTime) · \(event.venue)"
        case .ad(let ad): ad.merchant
        case .article: item.location?.name ?? ""
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HeroImage(url: item.imageUrl, height: 110, minimumCornerRadius: 12)
            Kicker(text: item.kind.label, color: item.kind.color)
            Text(item.title)
                .font(.system(size: 16, weight: .heavy, design: .serif))
                .foregroundStyle(Theme.ink)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(height: 42, alignment: .topLeading)
            Text(subtitle)
                .font(Theme.meta)
                .foregroundStyle(Theme.secondaryInk)
                .lineLimit(1)
        }
        .padding(10)
        .frame(width: 220)
        .background(Theme.surface, in: .rect(cornerRadius: 18))
        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
    }
}

private struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.title
            configuration.icon
        }
    }
}

private extension Array where Element == String {
    var uniqueCount: Int { Set(self).count }
}

#Preview {
    let env = AppEnvironment.preview()
    SummaryScreen()
        .environment(env)
        .environment(env.settings)
}
