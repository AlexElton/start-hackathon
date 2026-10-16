import SharedModels
import UIKit

/// The white card used by pins and clusters: title on top, picture below, optional pointer at the bottom.
/// `photoOnly` cards (behind the top card in a bunch) drop the title and badge and let the picture fill the card.
/// A `countBubble` is a circle merged into the frame at the top-right corner, for a bunch's count.
final class PinCardView: UIView {
    enum Layout {
        static let width: CGFloat = 84
        static let cardHeight: CGFloat = 110
        static let pointerHeight: CGFloat = 9
        static let pointerWidth: CGFloat = 16
        static let inset: CGFloat = 4
        static let titleHeight: CGFloat = 30
        static let cornerRadius: CGFloat = 14
        static let size = CGSize(width: width, height: cardHeight + pointerHeight)
    }

    private let cardLayer = CAShapeLayer()
    private var plainPath: UIBezierPath?
    private var bubblePath: UIBezierPath?
    private let titleLabel = UILabel()
    private let imageView = UIImageView()
    private let badge = UIImageView()
    private var imageTask: Task<Void, Never>?
    private(set) var itemId: String?

    /// Where the count bubble sits, in this view's coordinates: centred just inside the top-right corner.
    static let countBubbleFrame: CGRect = {
        let radius: CGFloat = 14
        let center = CGPoint(x: Layout.width - 5, y: 5)
        return CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
    }()

    init(showsPointer: Bool, photoOnly: Bool = false, countBubble: Bool = false) {
        super.init(frame: CGRect(origin: .zero, size: Layout.size))
        isUserInteractionEnabled = false

        let path = Self.cardPath(showsPointer: showsPointer)
        if countBubble {
            plainPath = path.copy() as? UIBezierPath
            // Same winding as the card, so the two fill and cast a shadow as one shape.
            path.append(UIBezierPath(ovalIn: Self.countBubbleFrame))
            bubblePath = path
        }
        cardLayer.path = path.cgPath
        cardLayer.fillColor = UIColor.white.cgColor
        cardLayer.shadowPath = path.cgPath
        cardLayer.shadowColor = UIColor.black.cgColor
        cardLayer.shadowOpacity = 0.25
        cardLayer.shadowRadius = 5
        cardLayer.shadowOffset = CGSize(width: 0, height: 2)
        layer.addSublayer(cardLayer)

        titleLabel.frame = CGRect(x: Layout.inset + 3, y: Layout.inset, width: Layout.width - 2 * (Layout.inset + 3), height: Layout.titleHeight)
        let titleFont = UIFont.systemFont(ofSize: 10.5, weight: .heavy)
        titleLabel.font = titleFont.fontDescriptor.withDesign(.serif).map { UIFont(descriptor: $0, size: 10.5) } ?? titleFont
        titleLabel.textColor = .black
        titleLabel.numberOfLines = 2
        titleLabel.lineBreakMode = .byTruncatingTail
        addSubview(titleLabel)

        titleLabel.isHidden = photoOnly
        badge.isHidden = photoOnly
        let imageTop = photoOnly ? Layout.inset : Layout.inset + Layout.titleHeight + 2
        imageView.frame = CGRect(x: Layout.inset, y: imageTop, width: Layout.width - 2 * Layout.inset, height: Layout.cardHeight - imageTop - Layout.inset)
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = Layout.cornerRadius - Layout.inset
        imageView.layer.cornerCurve = .continuous
        imageView.tintColor = .white
        addSubview(imageView)

        badge.frame = CGRect(x: imageView.frame.maxX - 22, y: imageView.frame.minY + 4, width: 18, height: 18)
        badge.contentMode = .center
        badge.tintColor = .white
        badge.layer.cornerRadius = 9
        badge.layer.borderColor = UIColor.white.cgColor
        badge.layer.borderWidth = 1.5
        addSubview(badge)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// Shows or hides the count bubble (cards made with `countBubble: true` only).
    func setCountBubbleVisible(_ visible: Bool) {
        guard let path = visible ? bubblePath : plainPath else { return }
        cardLayer.path = path.cgPath
        cardLayer.shadowPath = path.cgPath
    }

    /// Shows `item`. Does nothing if it already shows it, so calling this often is cheap.
    func configure(with item: FeedItem, images: ImageLoader) {
        guard item.id != itemId else { return }
        itemId = item.id
        titleLabel.text = item.title
        badge.backgroundColor = item.kind.uiColor
        badge.image = UIImage(systemName: item.kind.symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 8, weight: .bold))

        imageTask?.cancel()
        guard let url = ImageLoader.thumbnailURL(item.imageUrl, width: 240) else {
            showPlaceholder(for: item.kind)
            return
        }
        if let cached = images.cachedImage(for: url) {
            show(cached)
            return
        }
        showPlaceholder(for: item.kind)
        imageTask = Task { [weak self] in
            guard let image = await images.image(for: url), !Task.isCancelled, let self else { return }
            UIView.transition(with: imageView, duration: 0.2, options: .transitionCrossDissolve) {
                self.show(image)
            }
        }
    }

    func reset() {
        imageTask?.cancel()
        itemId = nil
        imageView.image = nil
        titleLabel.text = nil
    }

    private func show(_ image: UIImage) {
        imageView.contentMode = .scaleAspectFill
        imageView.backgroundColor = .clear
        imageView.image = image
    }

    private func showPlaceholder(for kind: ItemKind) {
        imageView.backgroundColor = kind.uiColor.withAlphaComponent(0.85)
        imageView.contentMode = .center
        imageView.image = UIImage(systemName: kind.symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold))
    }

    /// Rounded card with the pointer built into its bottom edge, as one outline so fill and shadow have no seams.
    private static func cardPath(showsPointer: Bool) -> UIBezierPath {
        let w = Layout.width, h = Layout.cardHeight, r = Layout.cornerRadius
        guard showsPointer else {
            return UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: w, height: h), cornerRadius: r)
        }
        let midX = w / 2, half = Layout.pointerWidth / 2, tip = h + Layout.pointerHeight
        let path = UIBezierPath()
        path.move(to: CGPoint(x: r, y: 0))
        path.addLine(to: CGPoint(x: w - r, y: 0))
        path.addArc(withCenter: CGPoint(x: w - r, y: r), radius: r, startAngle: -.pi / 2, endAngle: 0, clockwise: true)
        path.addLine(to: CGPoint(x: w, y: h - r))
        path.addArc(withCenter: CGPoint(x: w - r, y: h - r), radius: r, startAngle: 0, endAngle: .pi / 2, clockwise: true)
        path.addLine(to: CGPoint(x: midX + half, y: h))
        path.addLine(to: CGPoint(x: midX + 2, y: tip - 2))
        path.addQuadCurve(to: CGPoint(x: midX - 2, y: tip - 2), controlPoint: CGPoint(x: midX, y: tip))
        path.addLine(to: CGPoint(x: midX - half, y: h))
        path.addLine(to: CGPoint(x: r, y: h))
        path.addArc(withCenter: CGPoint(x: r, y: h - r), radius: r, startAngle: .pi / 2, endAngle: .pi, clockwise: true)
        path.addLine(to: CGPoint(x: 0, y: r))
        path.addArc(withCenter: CGPoint(x: r, y: r), radius: r, startAngle: .pi, endAngle: 3 * .pi / 2, clockwise: true)
        path.close()
        return path
    }
}

extension UIView {
    /// Small spring "pop" used when a pin or cluster appears.
    func popIn() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
        alpha = 0
        UIView.animate(withDuration: 0.45, delay: 0, usingSpringWithDamping: 0.62, initialSpringVelocity: 0.4, options: [.allowUserInteraction, .beginFromCurrentState]) {
            self.transform = .identity
            self.alpha = 1
        }
    }
}
