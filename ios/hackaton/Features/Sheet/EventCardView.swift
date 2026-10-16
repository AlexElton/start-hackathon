import SharedModels
import SwiftUI

/// Event card, opened straight at 90 %.
struct EventCardView: View {
    let item: FeedItem
    let details: FeedItem.EventDetails
    let paperName: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HeroImage(url: item.imageUrl, height: 240)
                    .overlay(alignment: .topLeading) {
                        if details.startsAt.isTonight {
                            Text("I KVELD")
                                .font(.system(size: 12, weight: .heavy))
                                .tracking(0.8)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Theme.trdby, in: .capsule)
                                .padding(14)
                        }
                    }
                    .padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 8) {
                    Kicker(text: "Arrangement", color: Theme.trdby)
                    Text(item.title)
                        .font(Theme.headline(26))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 20)

                VStack(alignment: .leading, spacing: 0) {
                    InfoRow(symbol: "calendar", text: details.startsAt.norwegianDay.capitalizedFirst)
                    Divider().padding(.leading, 44)
                    InfoRow(symbol: "clock", text: timeRange)
                    Divider().padding(.leading, 44)
                    InfoRow(symbol: "mappin.and.ellipse", text: details.venue)
                    if let price = details.price {
                        Divider().padding(.leading, 44)
                        InfoRow(symbol: "ticket", text: price)
                    }
                }
                .background(Theme.surface, in: .rect(cornerRadius: 16))
                .padding(.horizontal, 16)

                if let description = details.description {
                    Text(description)
                        .font(Theme.serifBody(18))
                        .foregroundStyle(Theme.ink)
                        .lineSpacing(3)
                        .padding(.horizontal, 20)
                }

                SourceBadge(paperName: paperName)
                    .padding(.horizontal, 20)
            }
            .padding(.top, 16)
            .padding(.bottom, 56)
            .containerRelativeFrame(.horizontal)
        }
        .scrollIndicators(.hidden)
    }

    private var timeRange: String {
        guard let end = details.endsAt else { return "Fra \(details.startsAt.norwegianTime)" }
        return "\(details.startsAt.norwegianTime)–\(end.norwegianTime)"
    }
}

/// Icon + text line used in event and ad cards.
struct InfoRow: View {
    let symbol: String
    let text: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.adressaBlue)
                .frame(width: 18)
            Text(text)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.ink)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
    }
}

#Preview {
    let item = FeedItem.samples[2]
    if case .event(let details) = item.details {
        EventCardView(item: item, details: details, paperName: "Adresseavisen")
            .background(Theme.background)
    }
}
