import SwiftUI

/// Design-tokens voor Bovexa Flow — 1:1 het "standaard"-thema uit
/// ~/Desktop/agenda-app/src/theme/tokens.ts: licht teal-grijs oppervlak,
/// witte glaskaarten, teal accent (geen losse hexcodes buiten dit bestand).
enum BovexaTheme {

    enum Category: String, CaseIterable, Decodable {
        case focus, work, social, body, afwezig
    }

    static func categoryColor(for category: Category) -> Color {
        switch category {
        case .focus: return Colors.categoryBlue
        case .work: return Colors.teal
        case .social: return Colors.categoryGreen
        case .body: return Colors.categoryLilac
        case .afwezig: return Colors.categoryAmber
        }
    }

    enum Colors {
        // achtergrond-gradient (licht teal-grijs, zoals de mockup)
        static let bgTop = Color(hex: "#DCE7E7")
        static let bgBottom = Color(hex: "#EDF3F2")
        static let page = Color(hex: "#DFE8E8")

        // inkt (donker op licht oppervlak)
        static let ink = Color(hex: "#10191A")
        static let inkSoft = Color(hex: "#203133")
        static let muted = Color(hex: "#5F6D70")

        // merk / teal accent
        static let teal = Color(hex: "#58AEB7")
        static let tealDark = Color(hex: "#2F858F")
        static let accent = Color(hex: "#2F858F")

        // categorie-accenten (focus/social/body/afwezig — work gebruikt teal)
        static let categoryBlue = Color(hex: "#7EB3DC")
        static let categoryGreen = Color(hex: "#A9D6B0")
        static let categoryLilac = Color(hex: "#C8B7E8")
        static let categoryAmber = Color(hex: "#E9B84F")

        // glas (wit-transparant op het lichte oppervlak)
        static let glassSoft = Color.white.opacity(0.42)
        static let glass = Color.white.opacity(0.52)
        static let glassStrong = Color.white.opacity(0.62)
        static let edge = Color.white.opacity(0.72)
        static let edgeSoft = Color.white.opacity(0.58)

        // navbar-chrome
        static let navSurface = Color.white.opacity(0.88)
        static let navBorder = Color.white.opacity(0.68)
        static let navInactive = Color(hex: "#5C6B78")

        // status
        static let danger = Color(hex: "#E45F55")
        static let white = Color.white
    }

    enum Gradients {
        static let teal = [Color(hex: "#69C4CC"), Color(hex: "#3B95A1")]
        static let tealSoft = [Color(hex: "#65BDC5"), Color(hex: "#3D98A4")]
        static let social = [Color(hex: "#BFE2BA"), Color(hex: "#78BD86")]
        static let body = [Color(hex: "#C7B7EB"), Color(hex: "#8F7ACA")]
        static let work = [Color(hex: "#65BDC5"), Color(hex: "#3B97A3")]
        static let barFill = [Color(hex: "#65BDC5"), Color(hex: "#88CF9E")]

        static let background = [BovexaTheme.Colors.bgTop, BovexaTheme.Colors.bgBottom]

        static let cardGlass = [Color.white.opacity(0.70), Color.white.opacity(0.50)]
        static let raisedGlass = [Color.white.opacity(0.74), Color.white.opacity(0.54)]
        static let pillGlass = [Color.white.opacity(0.78), Color.white.opacity(0.60)]
    }

    enum Radius {
        static let sm: CGFloat = 14
        static let md: CGFloat = 20
        static let lg: CGFloat = 26
        static let pill: CGFloat = 999
        static let phone: CGFloat = 48
    }

    enum Space {
        static let xs: CGFloat = 6
        static let sm: CGFloat = 10
        static let md: CGFloat = 14
        static let lg: CGFloat = 18
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    enum TypeScale {
        static let h1: CGFloat = 32
        static let h2: CGFloat = 24
        static let title: CGFloat = 17
        static let body: CGFloat = 14
        static let small: CGFloat = 13
        static let tiny: CGFloat = 11
    }

    enum Shadow {
        static let cardColor = Color(hex: "#375255")
        static let cardOpacity: Double = 0.18
        static let cardRadius: CGFloat = 24
        static let cardOffsetY: CGFloat = 16

        static let softColor = Color(hex: "#3C5C60")
        static let softOpacity: Double = 0.13
        static let softRadius: CGFloat = 16
        static let softOffsetY: CGFloat = 10

        static let tealGlowColor = Color(hex: "#2A8994")
        static let tealGlowOpacity: Double = 0.26
        static let tealGlowRadius: CGFloat = 18
        static let tealGlowOffsetY: CGFloat = 14
    }
}
