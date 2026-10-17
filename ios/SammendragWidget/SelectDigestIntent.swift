import AppIntents
import FeedEngine
import SharedModels

/// The summaries the widget can show, loaded from the same bundled data as the app.
enum DigestStore {
    static func all() -> [Digest] {
        (try? JSONContentRepository.bundled().digests) ?? []
    }
}

/// One summary, as a choice in the widget's settings.
struct DigestEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Sammendrag"
    static let defaultQuery = DigestQuery()

    let id: String
    let title: String
    let symbol: String

    init(_ digest: Digest) {
        id = digest.id
        title = digest.title
        symbol = digest.symbol
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)", image: .init(systemName: symbol))
    }
}

struct DigestQuery: EntityQuery {
    func entities(for identifiers: [DigestEntity.ID]) async throws -> [DigestEntity] {
        DigestStore.all().filter { identifiers.contains($0.id) }.map(DigestEntity.init)
    }

    func suggestedEntities() async throws -> [DigestEntity] {
        DigestStore.all().map(DigestEntity.init)
    }

    func defaultResult() async -> DigestEntity? {
        DigestStore.all().first.map(DigestEntity.init)
    }
}

/// "Rediger widget": pick which summary to show.
struct SelectDigestIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Velg sammendrag"
    static let description = IntentDescription("Velg hvilket sammendrag widgeten skal vise.")

    @Parameter(title: "Sammendrag")
    var digest: DigestEntity?
}
