import SwiftUI

/// Design-tokens voor Bovexa Flow — 1:1 het "standaard"-thema uit
/// ~/Desktop/agenda-app/src/theme/tokens.ts: licht teal-grijs oppervlak,
/// witte glaskaarten, teal accent (geen losse hexcodes buiten dit bestand).
enum BovexaTheme {

    enum Category: String, CaseIterable, Codable {
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
        // Achtergrond — "daglicht": koele teal-mist bovenin die naar warm zand
        // onderin zakt. Het glas heeft kleurverschil nodig om iets te breken;
        // een egale bijna-witte ondergrond maakt glas optisch onzichtbaar.
        static let bgTop = Color(hex: "#C4DFE2")
        static let bgMid = Color(hex: "#E1EDEA")
        static let bgBottom = Color(hex: "#F8F3EA")
        static let page = Color(hex: "#DFE8E8")

        // inkt (donker op licht oppervlak, met teal-zweem)
        static let ink = Color(hex: "#0E1A1C")
        static let inkSoft = Color(hex: "#24393B")
        /// v4: donkerder dan de oorspronkelijke #62787A. Die haalde op glas maar
        /// 4.1:1 — net onder AA, en op vol zonlicht onleesbaar. Nu 5.5:1, en nog
        /// steeds duidelijk ondergeschikt aan `ink` en `inkSoft`.
        static let muted = Color(hex: "#4E6467")

        // merk / teal accent
        static let teal = Color(hex: "#2AA1AD")
        static let tealDark = Color(hex: "#0B5C63")
        /// Tekst-accent: dieper dan `teal` zodat het leesbaar blijft op glas.
        static let accent = Color(hex: "#0B5C63")
        static let tealLight = Color(hex: "#8FD4DB")
        /// Warm tegenwicht voor de koele teal — gebruikt in de ondergrond en
        /// voor "rustig"-signalen (lege dag, afgeronde staat).
        static let warm = Color(hex: "#D9A45B")

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

        /// v3: drie stops — koel bovenin, warm onderin. Geeft het glas een
        /// kleurverloop om op te pikken (v2 was bijna-wit-op-bijna-wit,
        /// waardoor het glaseffect wegviel).
        static let backgroundSubtle = [
            BovexaTheme.Colors.bgTop,
            BovexaTheme.Colors.bgMid,
            BovexaTheme.Colors.bgBottom,
        ]

        static let cardGlass = [Color.white.opacity(0.70), Color.white.opacity(0.50)]
        static let raisedGlass = [Color.white.opacity(0.74), Color.white.opacity(0.54)]
        static let pillGlass = [Color.white.opacity(0.78), Color.white.opacity(0.60)]
    }

    /// v4: kleurvelden in de ondergrond. Glas breekt licht op *randen*, niet op
    /// egale vlakken — v3 blurde de velden zo ver (110-120) dat er alleen mist
    /// overbleef en het glas optisch mat werd. Deze orbs zijn strakker en staan
    /// zo dat hun rand door de kaartkolom loopt (kaarten lopen van ±5% tot ±95%
    /// van de schermbreedte), zodat elke kaart iets te breken heeft.
    ///
    /// Middelpunt en diameter zijn fracties: x/diameter van de schermbreedte,
    /// y van de schermhoogte.
    enum Orb {
        /// Koel veld linksboven; loopt tot ±0.58w, dwars door de hero-kaart.
        static let coolCenter = CGPoint(x: 0.10, y: 0.13)
        static let coolDiameter: CGFloat = 0.95
        static let coolBlur: CGFloat = 45
        static let coolOpacity: Double = 0.48

        /// Warm tegenwicht rechtsonder; linkerrand op ±0.45w.
        static let warmCenter = CGPoint(x: 0.88, y: 0.74)
        static let warmDiameter: CGFloat = 0.85
        static let warmBlur: CGFloat = 48
        static let warmOpacity: Double = 0.44

        /// Derde veld in de kaartzone (Tijdlijn / lijstkaarten). Middelpunt staat
        /// bewust *achter* de kaarten, zodat de afval van de orb over het
        /// kaartoppervlak loopt — dat verloop is wat het glas laat breken.
        static let midCenter = CGPoint(x: 0.72, y: 0.46)
        static let midDiameter: CGFloat = 0.70
        static let midBlur: CGFloat = 42
        static let midOpacity: Double = 0.44

        /// Lichtstreek langs de bovenrand. v3 zette hem op 0.55 over 28% van de
        /// hoogte — dat waste precies de zone uit waar de hero-kaart staat.
        static let topLightOpacity: Double = 0.22
        static let topLightHeight: CGFloat = 0.20
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

        /// Ruimte onderaan scrollende schermen. De zwevende tabbalk ligt óver de
        /// content: capsule (±54pt) + thuisindicator (±34pt) + ademruimte.
        /// Nagemeten op iPhone 17 Pro: de balk beslaat ±94pt vanaf de onderrand.
        static let tabBarClearance: CGFloat = 104
    }

    enum TypeScale {
        static let h1: CGFloat = 32
        static let h2: CGFloat = 24
        static let title: CGFloat = 17
        static let body: CGFloat = 14
        static let small: CGFloat = 13
        static let tiny: CGFloat = 11
    }

    /// v2 (Liquid Glass restyle): Dynamic Type-rollen i.p.v. vaste px-groottes,
    /// zodat tekst meeschaalt met de systeem-tekstgrootte-instelling van de
    /// gebruiker. `TypeScale` hierboven blijft intact voor schermen die nog niet
    /// zijn omgezet (plak 2-4) — beide tokensets bestaan tijdelijk naast elkaar.
    enum TypeStyle {
        static let largeTitle: Font = .largeTitle.bold()
        static let title: Font = .title.weight(.semibold)
        static let title2: Font = .title2.weight(.semibold)
        static let title3: Font = .title3.weight(.semibold)
        static let headline: Font = .headline
        static let body: Font = .body
        static let subheadline: Font = .subheadline
        static let footnote: Font = .footnote
        static let caption: Font = .caption

        /// SF Pro Rounded, voor cijfers/statistieken (stat-tegels, tellers).
        static let statNumber: Font = .system(.title, design: .rounded, weight: .bold)
        static let statLabel: Font = .system(.footnote, design: .rounded, weight: .medium)
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

    /// v2 (Liquid Glass restyle) tokens: bouwstenen voor GlassCard v2 en de
    /// nieuwe knopstijlen. Zie DESIGN-NOTES.md — `.glassEffect` bestaat en
    /// compileert op deze deploymentTarget (iOS 26), dus geen material-fallback
    /// nodig.
    enum Glass {
        /// Standaard hoekradius voor glaskaarten (zelfde als `Radius.lg`,
        /// hier als eigen token zodat glas-call-sites niet impliciet aan
        /// `Radius` gekoppeld hoeven te zijn).
        static let cardRadius: CGFloat = BovexaTheme.Radius.lg

        /// Teal-tint voor prominente/interactieve glaselementen (primaire knop,
        /// geselecteerde staat). Zelfde merkkleur als `Colors.teal`.
        static let tint: Color = BovexaTheme.Colors.teal
    }
}
