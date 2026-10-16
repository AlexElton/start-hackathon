import Foundation

/// Decodes a Polaris article export (the case's JSON format) as-is.
/// Only the fields we use are modelled; everything else (embeds, video, ads config) is ignored.
struct PolarisArticle: Decodable {
    let id: String
    let title: TextValue
    let urls: URLs
    let changes: Changes
    let section: Section?
    let newsroom: String?
    let authors: [Author]?
    let tags: [Tag]?
    let intro: Intro?
    let customProperties: CustomProperties?
    let components: [Component]

    struct TextValue: Decodable {
        let value: String
    }

    struct URLs: Decodable {
        let canonical: String
    }

    struct Changes: Decodable {
        let published: Date
        let updated: Date?
    }

    struct Section: Decodable {
        let title: String
    }

    struct Author: Decodable {
        let fullname: String
    }

    struct Tag: Decodable {
        let title: String
        let type: String?
    }

    struct ImageAsset: Decodable {
        let id: String?
    }

    struct CustomProperties: Decodable {
        let frontPageTitle: String?
        let presentation: String?
        let wordCount: Int?
        let frontPageImage: ImageAsset?
    }

    struct Intro: Decodable {
        let lead: String?
        let media: Component?
    }

    struct Paragraph: Decodable {
        let text: TextValue?
        let blockType: String?
    }

    /// One block of the article body. Polaris reuses keys with different shapes per `type`
    /// (e.g. `text` is a string value on `subheading` but a paragraph list on `who-is-who`),
    /// so every field is decoded leniently.
    struct Component: Decodable {
        let type: String
        let title: TextValue?
        let paragraphs: [Paragraph]
        let imageAsset: ImageAsset?
        let components: [Component]
        let text: TextValue?
        let summaryItems: [String]
        let presentationProperties: [String: String]

        private enum CodingKeys: String, CodingKey {
            case type, title, paragraphs, imageAsset, components, text, content, presentationProperties
        }

        private struct SummaryList: Decodable {
            struct Item: Decodable { let value: String }
            let items: [Item]
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            type = try container.decode(String.self, forKey: .type)
            title = try? container.decodeIfPresent(TextValue.self, forKey: .title)
            paragraphs = (try? container.decodeIfPresent([Paragraph].self, forKey: .paragraphs)) ?? []
            imageAsset = try? container.decodeIfPresent(ImageAsset.self, forKey: .imageAsset)
            components = (try? container.decodeIfPresent([Component].self, forKey: .components)) ?? []
            text = try? container.decodeIfPresent(TextValue.self, forKey: .text)
            summaryItems = ((try? container.decodeIfPresent([SummaryList].self, forKey: .content)) ?? [])
                .flatMap { $0.items.map(\.value) }
            presentationProperties = (try? container.decodeIfPresent([String: String].self, forKey: .presentationProperties)) ?? [:]
        }

        /// The first real image in this component or its children (video thumbnails have "@" ids).
        var firstImageId: String? {
            if let id = imageAsset?.id, !id.contains("@") { return id }
            return components.lazy.compactMap(\.firstImageId).first
        }
    }
}

extension PolarisArticle {
    static let imageBaseURL = "https://vcdn.polarismedia.no/"

    static func imageURL(id: String) -> String {
        "\(imageBaseURL)\(id)?w=1000&fit=clip&q=80"
    }

    /// Plain-text body in reading order. Headings and fact boxes become their own paragraphs;
    /// images, video and embeds are left out. Liveblogs have no text, so they get a pointer to the web.
    var bodyParagraphs: [String] {
        let paragraphs = textParagraphs
        guard paragraphs.isEmpty else { return paragraphs }
        let isLiveblog = components.contains { $0.type == "integration" }
        return [lead, isLiveblog ? "Saken oppdateres fortløpende. Les hele direkteblogg på adressa.no." : nil].compactMap { $0 }
    }

    private var textParagraphs: [String] {
        components.flatMap { component -> [String] in
            let paragraphs = component.paragraphs.compactMap { $0.text?.value.cleaned }
            switch component.type {
            case "text":
                return paragraphs
            case "subheading":
                return [component.text?.value.cleaned].compactMap { $0 }
            case "fact":
                let heading = [component.title?.value, component.presentationProperties["rgText"]]
                    .compactMap { $0?.cleaned }
                    .joined(separator: " – ")
                return (heading.isEmpty ? [] : [heading]) + paragraphs
            case "correction":
                return paragraphs.map { "Rettelse: \($0)" }
            default:
                return []
            }
        }
    }

    /// Bullet summary written by the newsroom, when the article has one.
    var newsroomSummary: [String] {
        components.first { $0.type == "article-summary" }?.summaryItems.compactMap(\.cleaned) ?? []
    }

    var lead: String? { intro?.lead?.cleaned }

    var author: String? {
        let names = (authors ?? []).map(\.fullname)
        return names.isEmpty ? nil : names.joined(separator: ", ")
    }

    var imageURL: String? {
        let id = customProperties?.frontPageImage?.id ?? intro?.media?.firstImageId
        return id.map(Self.imageURL(id:))
    }

    var readMinutes: Int {
        let words = customProperties?.wordCount.flatMap { $0 > 0 ? $0 : nil }
            ?? bodyParagraphs.reduce(0) { $0 + $1.split(separator: " ").count }
        return max(1, Int((Double(words) / 200).rounded()))
    }

    var tagTitles: [String] { (tags ?? []).map(\.title) }
}

private extension String {
    /// Trimmed, or nil when only whitespace.
    var cleaned: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
