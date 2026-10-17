import SharedModels
import SwiftUI

/// Student deal, opened straight at 90 %. Marked "ANNONSE" so it is never mistaken for journalism.
struct AdCardView: View {
    let item: FeedItem
    let details: FeedItem.AdDetails

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HeroImage(url: item.imageUrl, height: 240)
                    .padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Kicker(text: "Tilbud", color: Theme.korngul)
                        Spacer()
                        Text("ANNONSE")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(0.8)
                            .foregroundStyle(Theme.secondaryInk)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .overlay(Capsule().stroke(Theme.grey))
                    }
                    Text(details.merchant)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.secondaryInk)
                    Text(details.offer)
                        .font(Theme.headline(26))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 20)

                VStack(alignment: .leading, spacing: 0) {
                    InfoRow(symbol: "hourglass", text: "Gjelder til \(details.validUntil.norwegianDay)")
                    if let place = item.location?.name {
                        Divider().padding(.leading, 44)
                        InfoRow(symbol: "mappin.and.ellipse", text: place)
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

                Label("Vis studentbevis i kassen", systemImage: "person.text.rectangle")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.korngul.opacity(0.18), in: .capsule)
                    .padding(.horizontal, 20)
            }
            .padding(.top, 16)
            .padding(.bottom, 56)
            .containerRelativeFrame(.horizontal)
        }
        .scrollIndicators(.hidden)
    }
}
