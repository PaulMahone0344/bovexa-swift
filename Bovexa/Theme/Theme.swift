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
        case .work: return Colors.blue
        case .social: return Colors.categoryGreen
        case .body: return Colors.categoryLilac
        case .afwezig: return Colors.categoryAmber
        }
    }

    enum Colors {
        // Achtergrond — v5 "daglicht in blauw": lichtblauwe mist bovenin die naar
        // parelwit met een mintzweem onderin zakt. Het glas heeft kleurverschil
        // nodig om iets te breken; een egale bijna-witte ondergrond maakt glas
        // optisch onzichtbaar. Het temperatuurverschil dat v3/v4 uit teal-vs-zand
        // haalden, komt nu uit koningsblauw-vs-mint: mint trekt naar geel-groen en
        // staat daarmee ver genoeg van het diepe blauw af.
        static let bgTop = Color(hex: "#C9DCF2")
        static let bgMid = Color(hex: "#E4EDF6")
        /// Parelwit met een minimale mintzweem. De mint zelf zit in het hoekveld,
        /// niet in de verloopstop — anders kleurt de hele onderkant groen.
        static let bgBottom = Color(hex: "#F1F5F1")
        static let page = Color(hex: "#DDE7F1")

        // inkt (donker op licht oppervlak, met blauwzweem)
        static let ink = Color(hex: "#0B1526")
        static let inkSoft = Color(hex: "#22344A")
        /// v4-regel blijft: minstens 5.5:1 op glas, en duidelijk ondergeschikt aan
        /// `ink` en `inkSoft`. Nooit gebruiken voor tekst die direct op de
        /// ondergrond staat — daar is de ondergrond te verzadigd voor.
        static let muted = Color(hex: "#4C6076")

        // merk / blauw accent (v5: was teal, nu het koningsblauw van het logo)
        static let blue = Color(hex: "#2B5BC4")
        static let blueDeep = Color(hex: "#143A82")
        /// Tekst-accent: dieper dan `blue` zodat het leesbaar blijft op glas.
        static let accent = Color(hex: "#143A82")
        static let blueLight = Color(hex: "#A8C6F0")
        /// Koel tegenwicht onderin de ondergrond — de mint uit de wallpaper.
        static let mint = Color(hex: "#8FD8BE")
        /// Warm signaal (lege dag, afgeronde staat). Zit sinds v5 NIET meer in de
        /// ondergrond; amber op blauw is complementair en blijft goed leesbaar.
        static let warm = Color(hex: "#D9A45B")

        // Kleurvelden in de ondergrond. Eigen tokens, niet de merkkleur hergebruikt:
        // een orb moet lichter zijn dan het merkvlak, anders wordt de bovenhoek een
        // donkere plaat in plaats van licht dat het glas laat breken.
        static let orbCool = Color(hex: "#4A80D8")
        static let orbMid = Color(hex: "#A8C6F0")
        static let orbMint = Color(hex: "#8FD8BE")

        // categorie-accenten (focus/social/body/afwezig — work gebruikt `blue`).
        // v5: categoryBlue lag te dicht bij het nieuwe merkblauw en is naar cyaan
        // geschoven, zodat "werk" en "focus" uit elkaar te houden blijven.
        static let categoryBlue = Color(hex: "#5FBBD4")
        static let categoryGreen = Color(hex: "#8FD8BE")
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
        static let blue = [Color(hex: "#5B8FE0"), Color(hex: "#2B5BC4")]
        static let blueSoft = [Color(hex: "#6D9BE4"), Color(hex: "#3763C8")]
        static let social = [Color(hex: "#B7E5CE"), Color(hex: "#6BC29B")]
        static let body = [Color(hex: "#C7B7EB"), Color(hex: "#8F7ACA")]
        static let work = [Color(hex: "#5B8FE0"), Color(hex: "#2B5BC4")]
        static let barFill = [Color(hex: "#5B8FE0"), Color(hex: "#8FD8BE")]

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

        /// Koel tegenwicht rechtsonder. v5: kleiner, verder in de hoek en zwakker
        /// dan het warme veld dat hier stond. Mint op volle sterkte kleurde de hele
        /// onderste helft groen en gaf een vaal groengrijs waar het blauw eindigde;
        /// als hoekaccent doet het z'n werk zonder een tweede hoofdkleur te worden.
        static let warmCenter = CGPoint(x: 0.94, y: 0.86)
        static let warmDiameter: CGFloat = 0.62
        static let warmBlur: CGFloat = 48
        static let warmOpacity: Double = 0.30

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

    /// v5-naregel: deze kleuren waren nog uit de teal-tijd (#375255 / #3C5C60 /
    /// #2A8994). Een groenige schaduw onder een kaart die op koningsblauw ligt
    /// geeft de kaartrand een vuile zweem — het blauw en het groen doven elkaar
    /// uit tot grijs. De schaduw hoort kouder te zijn dan de ondergrond waarop
    /// hij valt, niet warmer en niet uit een andere kleurfamilie.
    enum Shadow {
        static let cardColor = Color(hex: "#2A3E5C")
        static let cardOpacity: Double = 0.18
        static let cardRadius: CGFloat = 24
        static let cardOffsetY: CGFloat = 16

        static let softColor = Color(hex: "#32496B")
        static let softOpacity: Double = 0.13
        static let softRadius: CGFloat = 16
        static let softOffsetY: CGFloat = 10

        static let blueGlowColor = Color(hex: "#1F4A9E")
        static let blueGlowOpacity: Double = 0.26
        static let blueGlowRadius: CGFloat = 18
        static let blueGlowOffsetY: CGFloat = 14
    }

    /// Vaste kleurenset voor labels (m7, valkuil F): geen vrije kleurkiezer, want
    /// die levert op het lichte glas onleesbare combinaties op (bv. lichtgeel op
    /// wit). Elke optie is gecontroleerd op leesbaarheid en te onderscheiden van
    /// de rest, in dezelfde donkere-op-licht-glas stijl als `MemberColors.palette`.
    /// Richting uit de schermafbeelding van de opdrachtgever: rood, oranje, geel,
    /// groen, teal, blauw, donkerblauw, paars, roze, bruin, grijs.
    enum LabelPalette {
        struct Option: Identifiable, Equatable {
            var id: String { hex }
            let name: String
            let hex: String
        }

        static let options: [Option] = [
            Option(name: "Rood", hex: "#D6524B"),
            Option(name: "Oranje", hex: "#E08A3C"),
            Option(name: "Geel", hex: "#C99A16"),
            Option(name: "Groen", hex: "#4F9E5C"),
            Option(name: "Teal", hex: "#2E9C97"),
            Option(name: "Blauw", hex: "#3E87D6"),
            Option(name: "Donkerblauw", hex: "#2C5C99"),
            Option(name: "Paars", hex: "#8E5BD1"),
            Option(name: "Roze", hex: "#D45AA4"),
            Option(name: "Bruin", hex: "#A56A3E"),
            Option(name: "Grijs", hex: "#6B7280"),
        ]
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
        /// geselecteerde staat). Zelfde merkkleur als `Colors.blue`.
        static let tint: Color = BovexaTheme.Colors.blue
    }
}
