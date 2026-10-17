import SharedModels
import SwiftUI
import UIKit

/// Adresseavisen's design tokens (see PLAN.md 3.6). Views use these, never raw colours.
enum Theme {
    // MARK: Brand palette (official hex from the Adresseavisen style guide)

    static let adressaBlue = Color(uiColor: .adressaBlue)
    static let cyan = Color(hex: "#28AAE2")
    static let grey = Color(hex: "#E2E2E2")
    static let paperBlue = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: "#16222C") : UIColor(hex: "#E5EDF5") })
    static let paperBeige = Color(hex: "#DFDED8")
    static let korngul = Color(uiColor: .korngul)
    static let trdby = Color(uiColor: .trdby)

    /// Text: Svart in light mode, white in dark mode.
    static let ink = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? .white : UIColor(hex: "#101010") })
    static let secondaryInk = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 1, alpha: 0.65) : UIColor(hex: "#101010").withAlphaComponent(0.62) })
    /// Screen and sheet background: Lys grå / near black.
    static let background = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: "#101010") : UIColor(hex: "#F6F6F6") })
    /// Cards on top of `background`.
    static let surface = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: "#1C1C1E") : .white })

    // MARK: Type (Acta → New York, Stag → SF heavy caps, Roboto → SF)

    static func headline(_ size: CGFloat) -> Font { .system(size: size, weight: .heavy, design: .serif) }
    static func serifBody(_ size: CGFloat = 18) -> Font { .system(size: size, weight: .regular, design: .serif) }
    static let lead = Font.system(size: 17, weight: .semibold)
    static let meta = Font.system(size: 13, weight: .medium)
    static let button = Font.system(size: 16, weight: .bold)
}

extension UIColor {
    static let adressaBlue = UIColor(hex: "#005379")
    static let korngul = UIColor(hex: "#F7A800")
    static let trdby = UIColor(hex: "#FF9E18")

    /// Parses "#RRGGBB". Falls back to gray.
    convenience init(hex: String) {
        let value = UInt64(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0x888888
        self.init(
            red: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }
}

/// Vignette in Stag style: small, heavy, uppercase, tracked.
struct Kicker: View {
    let text: String
    var color: Color = Theme.adressaBlue

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .heavy))
            .tracking(0.8)
            .foregroundStyle(color)
    }
}

/// "Fra Sunnmørsposten" with the paper's own logo. Falls back to its first letter in a blue circle
/// until the logo has loaded (or if it can't).
struct SourceBadge: View {
    let paperName: String

    var body: some View {
        HStack(spacing: 6) {
            AsyncImage(url: PaperLogos.url(for: paperName)) { phase in
                if case .success(let image) = phase {
                    image.resizable().scaledToFill()
                } else {
                    Text(String(paperName.prefix(1)))
                        .font(.system(size: 11, weight: .black, design: .serif))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Theme.adressaBlue)
                }
            }
            .frame(width: 20, height: 20)
            .clipShape(.rect(cornerRadius: 5))
            Text("Fra \(paperName)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.ink)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Primary button: solid Adressablå capsule.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.button)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Theme.adressaBlue, in: .capsule)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

/// Logos by paper name, filled in when the papers are loaded. Cards and the reader only get the paper's name,
/// so the badge looks the logo up here.
enum PaperLogos {
    nonisolated(unsafe) private static var byName: [String: URL] = [:]

    static func register(_ papers: [Paper]) {
        for paper in papers {
            if let url = paper.logoUrl.flatMap(URL.init(string:)) { byName[paper.name] = url }
        }
    }

    static func url(for paperName: String) -> URL? {
        byName[paperName]
    }
}
