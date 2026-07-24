import SwiftUI

/// Design-tokens voor Bovexa Flow — geport uit ~/Desktop/agenda-app/src/theme/tokens.ts
/// en themes.ts. Donkere gradient-achtergrond met teal accent, glaskaarten
/// (geen losse hexcodes buiten dit bestand).
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
        // achtergrond-gradient
        static let bgTop = Color(hex: "#0D2422")
        static let bgBottom = Color(hex: "#081513")
        static let page = Color(hex: "#0A1B19")

        // inkt (licht op donkere achtergrond)
        static let ink = Color(hex: "#F2F7F6")
        static let inkSoft = Color(hex: "#DCEAE8")
        static let muted = Color(hex: "#8FA6A4")

        // merk / teal accent
        static let teal = Color(hex: "#58AEB7")
        static let tealDark = Color(hex: "#2F858F")
        static let accent = Color(hex: "#7FCBD1")

        // categorie-accenten (focus/social/body/afwezig — work gebruikt teal)
        static let categoryBlue = Color(hex: "#7EB3DC")
        static let categoryGreen = Color(hex: "#A9D6B0")
        static let categoryLilac = Color(hex: "#C8B7E8")
        static let categoryAmber = Color(hex: "#E9B84F")

        // glas
        static let glassSoft = Color(hex: "#122B29")
        static let glass = Color(hex: "#173634")
        static let glassStrong = Color(hex: "#1D3F3C")
        static let edge = Color.white.opacity(0.10)
        static let edgeSoft = Color.white.opacity(0.055)

        // navbar-chrome
        static let navSurface = Color(hex: "#0F2624")
        static let navBorder = Color.white.opacity(0.09)
        static let navInactive = Color(hex: "#7FA3A0")

        // status
        static let danger = Color(hex: "#F0736A")
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

        static let cardGlass = [Color(hex: "#1A3D3A"), Color(hex: "#12302D")]
        static let raisedGlass = [Color(hex: "#234C48"), Color(hex: "#1B3F3B")]
        static let pillGlass = [Color(hex: "#20443F"), Color(hex: "#183633")]
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
        static let cardColor = Color(hex: "#03080F")
        static let cardOpacity: Double = 0.28
        static let cardRadius: CGFloat = 24
        static let cardOffsetY: CGFloat = 16

        static let softColor = Color(hex: "#03080F")
        static let softOpacity: Double = 0.20
        static let softRadius: CGFloat = 16
        static let softOffsetY: CGFloat = 10

        static let tealGlowColor = Color(hex: "#2A8994")
        static let tealGlowOpacity: Double = 0.30
        static let tealGlowRadius: CGFloat = 18
        static let tealGlowOffsetY: CGFloat = 14
    }
}
