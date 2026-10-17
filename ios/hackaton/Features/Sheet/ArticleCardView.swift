import SharedModels
import SwiftUI

/// Article card: photo, kicker, headline, lead, "Kort fortalt" and "Les hele saken".
struct ArticleCardView: View {
    let item: FeedItem
    let details: FeedItem.ArticleDetails
    let paperName: String
    let read: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HeroImage(url: item.imageUrl, height: 240)
                    .padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        // A long place name truncates; the date always shows in full.
                        Kicker(text: item.location?.name ?? item.kind.label)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(item.date.norwegianDay)
                            .font(Theme.meta)
                            .foregroundStyle(Theme.secondaryInk)
                            .fixedSize()
                    }
                    Text(item.title)
                        .font(Theme.headline(26))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    if let lead = details.lead {
                        Text(lead)
                            .font(Theme.lead)
                            .foregroundStyle(Theme.secondaryInk)
                    }
                }
                .padding(.horizontal, 20)

                if !details.summary.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Kicker(text: "Kort fortalt")
                        ForEach(details.summary, id: \.self) { point in
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Circle()
                                    .fill(Theme.adressaBlue)
                                    .frame(width: 6, height: 6)
                                    .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 1 }
                                Text(point)
                                    .font(Theme.serifBody(17))
                                    .foregroundStyle(Theme.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.paperBlue, in: .rect(cornerRadius: 16))
                    .padding(.horizontal, 16)
                }

                HStack {
                    SourceBadge(paperName: paperName)
                    Spacer()
                    Label("\(details.readMinutes) min", systemImage: "clock")
                        .font(Theme.meta)
                        .foregroundStyle(Theme.secondaryInk)
                }
                .padding(.horizontal, 20)

                Button("Les hele saken", action: read)
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, 20)
            }
            .padding(.top, 16)
            .padding(.bottom, 56)
            .containerRelativeFrame(.horizontal)
        }
        .scrollIndicators(.hidden)
    }
}

#Preview {
    let item = FeedItem.samples[0]
    if case .article(let details) = item.details {
        ArticleCardView(item: item, details: details, paperName: "Adresseavisen") {}
            .background(Theme.background)
    }
}
