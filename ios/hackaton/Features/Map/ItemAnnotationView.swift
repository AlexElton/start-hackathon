import MapKit
import SharedModels

/// One pin. Joins MapKit clustering through `clusteringIdentifier`.
final class ItemAnnotationView: MKAnnotationView {
    static let reuseIdentifier = "ItemAnnotationView"
    static let clusteringIdentifier = "feed"

    var images: ImageLoader?
    private let card = PinCardView(showsPointer: true)

    override init(annotation: (any MKAnnotation)?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        frame = CGRect(origin: .zero, size: PinCardView.Layout.size)
        centerOffset = CGPoint(x: 0, y: -frame.height / 2) // Pointer tip sits on the coordinate.
        canShowCallout = false
        clusteringIdentifier = Self.clusteringIdentifier
        collisionMode = .rectangle
        displayPriority = .defaultHigh
        addSubview(card)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func refresh() {
        guard let item = (annotation as? ItemAnnotation)?.item, let images else { return }
        card.configure(with: item, images: images)
    }

    override var annotation: (any MKAnnotation)? {
        willSet { clusteringIdentifier = Self.clusteringIdentifier }
    }

    override func prepareForDisplay() {
        super.prepareForDisplay()
        refresh()
        // Animate the card, never the view itself: MapKit groups pins by the views' frames,
        // so a shrunken view mid-animation would stop overlapping pins from forming a bunch.
        card.popIn()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        card.reset()
    }
}
