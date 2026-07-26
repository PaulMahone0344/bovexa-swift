import SwiftUI

/// Nadruk van een glasoppervlak. Zonder onderscheid krijgt elk vlak op een
/// scherm hetzelfde gewicht en verdwijnt de hiërarchie — v2 had dat probleem.
enum GlassEmphasis {
    /// Belangrijkste vlak op het scherm: teal-getint, lichte rand, diepe schaduw.
    case hero
    /// Standaard kaart.
    case standard
    /// Ondergeschikt vlak (statistiek-pillen, terzijdes): vlakker, minder schaduw.
    case quiet
}

/// Glaskaart v3: echt systeemglas met drie nadruk-niveaus.
struct GlassCard<Content: View>: View {
    var radius: CGFloat = BovexaTheme.Radius.lg
    var padding: CGFloat = BovexaTheme.Space.lg
    var emphasis: GlassEmphasis = .standard
    @ViewBuilder var content: () -> Content

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }

    /// v5-naregel: de tint stond op 0.22, afgeregeld op het oude teal. Koningsblauw
    /// is veel dieper en verzadigder, dus dezelfde 0.22 maakte van elke hero-kaart
    /// een massieve blauwe plaat (Dagtaken-composer, bedrijfskaart) die naast de
    /// witte kaarten eronder als een ander scherm las. Nadruk moet uit een zweem
    /// komen, niet uit een vlak.
    private var glass: Glass {
        switch emphasis {
        case .hero: return .regular.tint(BovexaTheme.Colors.blue.opacity(0.10))
        case .standard, .quiet: return .regular
        }
    }

    /// v4: geen uniforme rand meer. Echt glas vangt licht ongelijk — fel langs de
    /// bovenrand, weg aan de onderkant. Een even sterke rand rondom leest als een
    /// getekend kadertje en dat maakte de kaarten mat.
    private var strokeGradient: LinearGradient {
        let colors: [Color]
        switch emphasis {
        case .hero:
            colors = [BovexaTheme.Colors.blueLight.opacity(0.85), BovexaTheme.Colors.blue.opacity(0.15)]
        case .standard:
            colors = [Color.white.opacity(0.75), Color.white.opacity(0.10)]
        case .quiet:
            colors = [Color.white.opacity(0.50), Color.white.opacity(0.08)]
        }
        return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }

    /// Binnenglans over de bovenrand: de "lichtstrijk" die anders volledig van de
    /// ondergrond moet komen. Geclipt op de kaartvorm.
    private var topSheen: some View {
        LinearGradient(
            colors: [Color.white.opacity(emphasis == .quiet ? 0.10 : 0.18), Color.white.opacity(0)],
            startPoint: .top,
            endPoint: .bottom
        )
        .clipShape(shape)
        .allowsHitTesting(false)
    }

    // v4: schaduwen lichter en korter. De vorige waardes (radius 26 met een
    // gloed van 0.30) gaven elke kaart een wolk eronder, wat het scherm zacht
    // en onscherp maakte. Minder blur zet de kaartrand strakker neer.
    private var shadowColor: Color {
        switch emphasis {
        case .hero: return BovexaTheme.Shadow.blueGlowColor.opacity(0.18)
        case .standard: return BovexaTheme.Shadow.softColor.opacity(0.10)
        case .quiet: return BovexaTheme.Shadow.softColor.opacity(0.05)
        }
    }

    private var shadowRadius: CGFloat {
        switch emphasis {
        case .hero: return 16
        case .standard: return 10
        case .quiet: return 5
        }
    }

    private var shadowOffset: CGFloat {
        switch emphasis {
        case .hero: return 9
        case .standard: return 5
        case .quiet: return 3
        }
    }

    var body: some View {
        content()
            .padding(padding)
            .glassEffect(glass, in: shape)
            .overlay(topSheen)
            .overlay(shape.stroke(strokeGradient, lineWidth: 0.8))
            .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowOffset)
    }
}

#Preview {
    ZStack {
        AppBackground()
        VStack(spacing: BovexaTheme.Space.lg) {
            GlassCard(emphasis: .hero) {
                Text("Hero").foregroundStyle(BovexaTheme.Colors.ink)
            }
            GlassCard {
                Text("Standaard").foregroundStyle(BovexaTheme.Colors.ink)
            }
            GlassCard(emphasis: .quiet) {
                Text("Rustig").foregroundStyle(BovexaTheme.Colors.ink)
            }
        }
        .padding()
    }
}
