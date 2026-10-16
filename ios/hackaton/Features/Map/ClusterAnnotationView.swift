import MapKit
import SharedModels

/// A bunch of pins: the newest on top, up to two smaller cards tucked behind it peeking out left and right,
/// and the count in a bubble that is part of the top card's white frame.
/// The fan is seeded from the member ids, so the same bunch always looks the same and never jitters.
final class ClusterAnnotationView: MKAnnotationView {
    private enum Layout {
        static let margin: CGFloat = 24
        static let maxBackCards = 2
        static let size = CGSize(
            width: PinCardView.Layout.width + 2 * margin,
            height: PinCardView.Layout.size.height + margin
        )
    }

    var images: ImageLoader?
    /// Holds everything, so the pop-in animates this and not the annotation view's frame.
    private let content = UIView()
    private let backCards = (0..<Layout.maxBackCards).map { _ in PinCardView(showsPointer: false, photoOnly: true) }
    private let topCard = PinCardView(showsPointer: true, countBubble: true)
    private let countLabel = UILabel()
    private var memberIds: [String] = []

    override init(annotation: (any MKAnnotation)?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        frame = CGRect(origin: .zero, size: Layout.size)
        centerOffset = CGPoint(x: 0, y: -frame.height / 2) // Top card's pointer tip sits on the coordinate.
        canShowCallout = false
        collisionMode = .rectangle
        displayPriority = .required
        content.frame = bounds
        addSubview(content)

        let cardOrigin = CGPoint(x: Layout.margin, y: Layout.margin)
        for card in backCards.reversed() {
            card.frame.origin = cardOrigin
            content.addSubview(card)
        }
        topCard.frame.origin = cardOrigin
        content.addSubview(topCard)

        countLabel.frame = PinCardView.countBubbleFrame.offsetBy(dx: cardOrigin.x, dy: cardOrigin.y).insetBy(dx: 3, dy: 3)
        countLabel.textColor = .black
        countLabel.font = .systemFont(ofSize: 13, weight: .heavy)
        countLabel.textAlignment = .center
        countLabel.adjustsFontSizeToFitWidth = true
        countLabel.minimumScaleFactor = 0.6
        content.addSubview(countLabel)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// Newest first, so the top card is the freshest story. An article with several pins appears once.
    static func sortedItems(in cluster: MKClusterAnnotation) -> [FeedItem] {
        cluster.memberAnnotations
            .compactMap { ($0 as? ItemAnnotation)?.item }
            .sorted { $0.date != $1.date ? $0.date > $1.date : $0.id < $1.id }
            .uniquedByArticle()
    }

    func refresh() {
        guard let cluster = annotation as? MKClusterAnnotation, let images else { return }
        let items = Self.sortedItems(in: cluster)
        guard let top = items.first else { return }
        let ids = items.map(\.id)
        countLabel.text = items.count > 99 ? "99+" : "\(items.count)"
        countLabel.isHidden = items.count < 2
        topCard.setCountBubbleVisible(items.count > 1)
        topCard.configure(with: top, images: images)

        guard ids != memberIds else { return }
        memberIds = ids
        var generator = SeededGenerator(seed: ids.joined(separator: "|"))
        for (index, card) in backCards.enumerated() {
            guard index + 1 < items.count else {
                card.isHidden = true
                continue
            }
            card.isHidden = false
            card.configure(with: items[index + 1], images: images)
            card.transform = Self.fanTransform(depth: index + 1, using: &generator)
        }
    }

    /// Cards behind are a bit smaller and peek out on alternating sides (left first, then right),
    /// tilted slightly outwards. A small seeded jitter keeps bunches from looking stamped.
    private static func fanTransform(depth: Int, using generator: inout SeededGenerator) -> CGAffineTransform {
        let side: CGFloat = depth.isMultiple(of: 2) ? 1 : -1
        let row = CGFloat((depth + 1) / 2) // 1, 1, 2, 2, ... so left and right sit at the same depth.
        let angle = side * CGFloat(Double.random(in: 3.5...6, using: &generator)) * .pi / 180
        let dx = side * (CGFloat(Double.random(in: 24...28, using: &generator)) * row)
        let dy = CGFloat(Double.random(in: 2...5, using: &generator))
        let scale = 1 - 0.13 * row
        return CGAffineTransform(translationX: dx, y: dy)
            .rotated(by: angle)
            .scaledBy(x: scale, y: scale)
    }

    override func prepareForDisplay() {
        super.prepareForDisplay()
        refresh()
        content.popIn()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        memberIds = []
        topCard.reset()
        backCards.forEach { $0.reset() }
    }
}

/// Deterministic random numbers from a string seed (FNV-1a + SplitMix64), stable across launches.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: String) {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in seed.utf8 {
            hash = (hash ^ UInt64(byte)) &* 0x100000001b3
        }
        state = hash
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
