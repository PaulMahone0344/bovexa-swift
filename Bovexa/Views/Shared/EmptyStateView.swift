import SwiftUI

/// Waar de lege staat op ligt. Dit bepaalt de tekstkleur: `muted` haalt zijn
/// 5.5:1 alleen op wit glas, en verschiet op de blauwe ondergrond tot een
/// grijze veeg. De v4-regel zegt dan ook: tekst die direct op de ondergrond
/// staat nooit in `muted`, maar in `inkSoft`.
enum EmptyStateSurface {
    case glass
    case background
}

/// Lege staat: icoon + tekst, native stijl. Herbruikbaar op elk scherm met een
/// leeg-resultaat (geen afspraken, geen zoekresultaat, geen collega's, ...).
struct EmptyStateView: View {
    let systemImage: String
    let text: String
    var surface: EmptyStateSurface = .glass

    private var textColor: Color {
        switch surface {
        case .glass: return BovexaTheme.Colors.muted
        case .background: return BovexaTheme.Colors.inkSoft
        }
    }

    /// Het icoon blijft een halve trap zachter dan de tekst, zodat de lege staat
    /// ook op de ondergrond ondergeschikt blijft aan de kop erboven.
    private var iconColor: Color {
        switch surface {
        case .glass: return BovexaTheme.Colors.muted
        case .background: return BovexaTheme.Colors.inkSoft.opacity(0.72)
        }
    }

    var body: some View {
        VStack(spacing: BovexaTheme.Space.sm) {
            Image(systemName: systemImage)
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(iconColor)
            Text(text)
                .font(BovexaTheme.TypeStyle.subheadline)
                .foregroundStyle(textColor)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, BovexaTheme.Space.lg)
    }
}

#Preview {
    ZStack {
        AppBackground()
        VStack(spacing: BovexaTheme.Space.xl) {
            GlassCard {
                EmptyStateView(systemImage: "calendar", text: "Nog niks gepland vandaag…")
            }
            EmptyStateView(
                systemImage: "person.2",
                text: "Nog geen privécontacten.",
                surface: .background
            )
        }
        .padding()
    }
}
