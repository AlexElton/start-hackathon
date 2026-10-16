import Foundation
import SharedModels

/// What the item sheet shows: one item, or a bunch to page through. Articles appear once even if they have several pins.
struct ItemSelection: Identifiable {
    let id = UUID()
    let items: [FeedItem]

    init?(items: [FeedItem]) {
        let unique = items.uniquedByArticle()
        guard !unique.isEmpty else { return nil }
        self.items = unique
    }

    /// One layer is shown at a time, so a selection has one kind.
    var kind: ItemKind { items[0].kind }
}
