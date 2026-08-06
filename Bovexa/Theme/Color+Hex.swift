import SwiftUI
import UIKit

extension Color {
    /// Parseert "#RRGGBB" of "RRGGBB". Alleen dit formaat komt voor in tokens.ts/themes.ts.
    init(hex: String) {
        let clean = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        var value: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&value)
        let r = Double((value & 0xFF0000) >> 16) / 255.0
        let g = Double((value & 0x00FF00) >> 8) / 255.0
        let b = Double(value & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b)
    }

    /// Terug naar "#RRGGBB" — voor kleuren uit de vrije ColorPicker, die als hex
    /// naar de server gaan (zelfde opslagformaat als de vaste swatches). Extended
    /// range kleuren worden op sRGB geklemd, want de hex-parser hierboven kan
    /// alleen 0-255 aan.
    var hexString: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        func channel(_ value: CGFloat) -> Int { Int(round(min(max(value, 0), 1) * 255)) }
        return String(format: "#%02X%02X%02X", channel(r), channel(g), channel(b))
    }
}
