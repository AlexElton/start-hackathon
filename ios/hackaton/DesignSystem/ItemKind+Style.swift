import SharedModels
import SwiftUI

/// Name, icon and colour per layer. Shared by the filter chips, pins and sheets.
extension ItemKind {
    var title: String {
        switch self {
        case .article: "Saker"
        case .event: "Arrangementer"
        case .ad: "Tilbud"
        }
    }

    /// Kicker on cards.
    var label: String {
        switch self {
        case .article: "Sak"
        case .event: "Arrangement"
        case .ad: "Tilbud"
        }
    }

    var symbol: String {
        switch self {
        case .article: "newspaper.fill"
        case .event: "calendar"
        case .ad: "tag.fill"
        }
    }

    /// Saker = Adressablå, Arrangementer = Trd.by orange, Tilbud = Korngul (commercial).
    var uiColor: UIColor {
        switch self {
        case .article: .adressaBlue
        case .event: .trdby
        case .ad: .korngul
        }
    }

    var color: Color { Color(uiColor: uiColor) }
}

extension FeedItem {
    /// Pins of the same article share this, so a bunch and the sheet count the article once.
    var groupKey: String {
        if case .article(let details) = details { return details.articleId }
        return id
    }
}

extension Array where Element == FeedItem {
    /// Keeps the first item per `groupKey`, in order.
    func uniquedByArticle() -> [FeedItem] {
        var seen = Set<String>()
        return filter { seen.insert($0.groupKey).inserted }
    }
}
