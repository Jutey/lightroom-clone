import SwiftUI

/// The app's brand colors. `sage` is the accent (buttons, selections, highlights); the
/// others are available for chrome/background theming elsewhere in the UI.
enum BrandPalette {
    static let deepGreen = Color(hex: "002F25")
    static let sage = Color(hex: "798F5D")
    static let mist = Color(hex: "B4BCBA")
    static let ink = Color(hex: "0E0607")
}

extension Color {
    init(hex: String) {
        var hexValue = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexValue.removeAll { $0 == "#" }
        var rgb: UInt64 = 0
        Scanner(string: hexValue).scanHexInt64(&rgb)
        self.init(
            red: Double((rgb & 0xFF0000) >> 16) / 255,
            green: Double((rgb & 0x00FF00) >> 8) / 255,
            blue: Double(rgb & 0x0000FF) / 255
        )
    }
}
