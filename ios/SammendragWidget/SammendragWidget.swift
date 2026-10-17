import SharedModels
import SwiftUI
import UIKit
import WidgetKit

struct DigestEntry: TimelineEntry {
    let date: Date
    let digest: Digest
    /// Downloaded ahead of time: widgets can't load images from the internet while they draw.
    let image: UIImage?

    static let placeholder = DigestEntry(
        date: .now,
        digest: Digest(
            id: "i-dag", scope: .day, title: "I dag", kicker: nil,
            headline: "Brannene er slukket, og kvelden er din",
            intro: "",
            points: [
                .init(title: "Kornbrannen i Ila er slukket", text: ""),
                .init(title: "Mann siktet etter knivstikking", text: ""),
                .init(title: "350 søkere kjemper om 32 legejobber", text: ""),
            ],
            itemIds: [], imageUrl: nil, symbol: "sun.max.fill", color: "#005379",
            categoryId: nil, regionId: nil, readMinutes: 2
        ),
        image: nil
    )
}

struct DigestProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> DigestEntry { .placeholder }

    func snapshot(for configuration: SelectDigestIntent, in context: Context) async -> DigestEntry {
        await entry(for: configuration)
    }

    func timeline(for configuration: SelectDigestIntent, in context: Context) async -> Timeline<DigestEntry> {
        let entry = await entry(for: configuration)
        // Refresh every few hours, and right after midnight so "I dag" shows the new date.
        let soon = Calendar.current.date(byAdding: .hour, value: 3, to: .now) ?? .now
        let midnight = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now)
        return Timeline(entries: [entry], policy: .after(min(soon, midnight)))
    }

    private func entry(for configuration: SelectDigestIntent) async -> DigestEntry {
        let digests = DigestStore.all()
        guard let digest = digests.first(where: { $0.id == configuration.digest?.id }) ?? digests.first else {
            return .placeholder
        }
        return DigestEntry(date: .now, digest: digest, image: await Self.image(for: digest))
    }

    /// Downloads and shrinks the photo; widgets have a tight memory limit.
    private static func image(for digest: Digest) async -> UIImage? {
        guard let string = digest.imageUrl,
              var components = URLComponents(string: string) else { return nil }
        components.queryItems = (components.queryItems ?? []).filter { $0.name != "w" } + [URLQueryItem(name: "w", value: "700")]
        guard let url = components.url,
              let (data, _) = try? await URLSession.shared.data(from: url),
              let image = UIImage(data: data) else { return nil }
        return await image.byPreparingThumbnail(ofSize: CGSize(width: 700, height: 700 * image.size.height / max(image.size.width, 1))) ?? image
    }
}

struct SammendragWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "Sammendrag", intent: SelectDigestIntent.self, provider: DigestProvider()) { entry in
            SammendragWidgetView(entry: entry)
        }
        .configurationDisplayName("Sammendrag")
        .description("Kort fortalt fra Adresseavisen. Velg I dag, Denne uka, et tema eller et sted.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Views

struct SammendragWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DigestEntry

    private var digest: Digest { entry.digest }

    var body: some View {
        Group {
            switch family {
            case .systemSmall: small
            case .systemMedium: medium
            default: large
            }
        }
        .widgetURL(URL(string: "hackaton://sammendrag/\(digest.id)"))
    }

    // Photo with the headline on top.
    private var small: some View {
        VStack(alignment: .leading, spacing: 5) {
            Spacer(minLength: 0)
            KickerTag(text: digest.widgetKicker, color: digest.accent)
            Text(digest.headline)
                .font(.system(size: 15, weight: .heavy, design: .serif))
                .foregroundStyle(.white)
                .lineLimit(4)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(for: .widget) {
            PhotoBackground(image: entry.image, accent: digest.accent)
        }
    }

    // Text on the left, photo on the right.
    private var medium: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Kicker(text: digest.widgetKicker, color: digest.accent)
                Text(digest.headline)
                    .font(.system(size: 16, weight: .heavy, design: .serif))
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)
                Spacer(minLength: 0)
                PointList(points: Array(digest.points.prefix(2)), accent: digest.accent, size: 12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Photo(image: entry.image, accent: digest.accent)
                .frame(width: 112)
                .clipShape(.rect(cornerRadius: 14))
        }
        .containerBackground(.background, for: .widget)
    }

    // Photo with headline on top, then the points.
    private var large: some View {
        VStack(alignment: .leading, spacing: 12) {
            Photo(image: entry.image, accent: digest.accent)
                .frame(height: 150)
                .overlay {
                    LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .center, endPoint: .bottom)
                }
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: 5) {
                        KickerTag(text: digest.widgetKicker, color: digest.accent)
                        Text(digest.headline)
                            .font(.system(size: 19, weight: .heavy, design: .serif))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                    }
                    .padding(12)
                }
                .clipShape(.rect(cornerRadius: 16))
            PointList(points: Array(digest.points.prefix(4)), accent: digest.accent, size: 13.5)
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                Text("A")
                    .font(.system(size: 9, weight: .black, design: .serif))
                    .foregroundStyle(.white)
                    .frame(width: 16, height: 16)
                    .background(Color.adressaBlue, in: .circle)
                Text("Fra Adresseavisen")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(digest.readMinutes) min")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .containerBackground(.background, for: .widget)
    }
}

/// Point titles with a small accent dot; no numbers, so it reads as news, not steps.
private struct PointList: View {
    let points: [Digest.Point]
    let accent: Color
    let size: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: size * 0.55) {
            ForEach(points, id: \.title) { point in
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Circle()
                        .fill(accent)
                        .frame(width: 5, height: 5)
                        .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 1 }
                    Text(point.title)
                        .font(.system(size: size, weight: .semibold, design: .serif))
                        .lineLimit(2)
                }
            }
        }
    }
}

private struct Kicker: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .heavy))
            .tracking(0.6)
            .foregroundStyle(color)
            .lineLimit(1)
    }
}

private struct KickerTag: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .heavy))
            .tracking(0.6)
            .foregroundStyle(.white)
            .lineLimit(1)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color, in: .capsule)
    }
}

private struct Photo: View {
    let image: UIImage?
    let accent: Color

    var body: some View {
        Rectangle()
            .fill(accent.opacity(0.25))
            .overlay {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                }
            }
            .clipped()
    }
}

private struct PhotoBackground: View {
    let image: UIImage?
    let accent: Color

    var body: some View {
        ZStack {
            accent
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            }
            LinearGradient(colors: [.black.opacity(0.05), .black.opacity(0.8)], startPoint: .top, endPoint: .bottom)
        }
    }
}

private extension Digest {
    var accent: Color { Color(hex: color) }

    /// Same labels as in the app: today's date, the week number, or the topic/place.
    var widgetKicker: String {
        switch scope {
        case .day: return Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "nb_NO")))
        case .week: return "Uke \(Calendar(identifier: .iso8601).component(.weekOfYear, from: .now))"
        case .category, .place: return kicker ?? title
        }
    }
}

extension Color {
    static let adressaBlue = Color(red: 0, green: 83 / 255, blue: 121 / 255)

    init(hex: String) {
        let value = UInt64(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0x888888
        self.init(red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255, blue: Double(value & 0xFF) / 255)
    }
}

#Preview(as: .systemMedium) {
    SammendragWidget()
} timeline: {
    DigestEntry.placeholder
}
