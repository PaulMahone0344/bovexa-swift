import SwiftUI

/// Eén regel onder een lijst die niet ververst kon worden (M11 plak 4a). De
/// gegevens die er staan zijn de laatst geladen; zonder deze regel lijkt een
/// verouderde lijst gewoon de waarheid, of — vóór M11 — leek een lege lijst te
/// betekenen dat er niets was.
///
/// Bewust geen alert en geen knop: de gebruiker doet hier niets mee behalve
/// weten dat het even niet lukte. Verversen gaat via pull-to-refresh of vanzelf
/// bij de volgende poging.
struct LoadFailedNote: View {
    var text = "Geen verbinding — toont laatst geladen gegevens."
    /// `.background` als de regel direct op de ondergrond staat: `muted` is daar
    /// te licht (zie DE VISUELE TAAL in de handoff).
    var surface: Surface = .glass

    enum Surface {
        case glass
        case background
    }

    var body: some View {
        HStack(spacing: BovexaTheme.Space.xs) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 12, weight: .semibold))
            Text(text)
                .font(BovexaTheme.TypeStyle.footnote)
        }
        .foregroundStyle(surface == .glass ? BovexaTheme.Colors.muted : BovexaTheme.Colors.inkSoft)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ZStack {
        AppBackground()
        VStack(spacing: BovexaTheme.Space.lg) {
            GlassCard { LoadFailedNote() }
            LoadFailedNote(surface: .background)
        }
        .padding()
    }
}
