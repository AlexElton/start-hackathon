import SharedModels
import SwiftUI

extension Color {
    /// Parses "#RRGGBB" as used by categories and papers. Falls back to gray.
    init(hex: String) {
        let value = UInt64(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0x888888
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}

extension SharedModels.Category {
    var swiftUIColor: Color { Color(hex: color) }
}
