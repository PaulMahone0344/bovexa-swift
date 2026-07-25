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

    private var glass: Glass {
        switch emphasis {
        case .hero: return .regular.tint(BovexaTheme.Colors.teal.opacity(0.22))
        case .standard, .quiet: return .regular
        }
    }

    private var strokeColor: Color {
        switch emphasis {
        case .hero: return BovexaTheme.Colors.teal.opacity(0.45)
        case .standard: return Color.white.opacity(0.5)
        case .quiet: return Color.white.opacity(0.35)
        }
    }

    private var shadowColor: Color {
        switch emphasis {
        case .hero: return BovexaTheme.Shadow.tealGlowColor.opacity(0.30)
        case .standard: return BovexaTheme.Shadow.softColor.opacity(0.16)
        case .quiet: return BovexaTheme.Shadow.softColor.opacity(0.08)
        }
    }

    private var shadowRadius: CGFloat {
        switch emphasis {
        case .hero: return 26
        case .standard: return 16
        case .quiet: return 8
        }
    }

    private var shadowOffset: CGFloat {
        switch emphasis {
        case .hero: return 16
        case .standard: return 9
        case .quiet: return 4
        }
    }

    var body: some View {
        content()
            .padding(padding)
            .glassEffect(glass, in: shape)
            .overlay(shape.stroke(strokeColor, lineWidth: 0.8))
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
