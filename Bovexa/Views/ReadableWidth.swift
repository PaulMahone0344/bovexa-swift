import SwiftUI

/// Begrenst de inhoud tot een leesbare kolom en zet die in het midden.
///
/// De app is ontworpen voor een telefoon. Op een iPad (verplicht sinds de
/// store-update van 27 juli) rekte elke kaart mee tot de volle breedte: een
/// afspraak-rij werd dan een halve meter tekst met een cijfer helemaal rechts,
/// en de tijdlijn-lijn stond kilometers van de titel. Een vaste kolom houdt het
/// beeld hetzelfde als op de telefoon, met lucht eromheen.
struct ReadableWidthModifier: ViewModifier {
    /// Ruim genoeg voor een grote telefoon, smal genoeg om op een iPad niet uit
    /// elkaar te vallen.
    private static let maxWidth: CGFloat = 620

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: Self.maxWidth)
            .frame(maxWidth: .infinity)
            // De ondergrond hoort tot de schermrand door te lopen. Elk scherm
            // tekent zijn eigen AppBackground, maar die zit binnen de kolom en
            // liet links en rechts een witte baan staan.
            .background(AppBackground().ignoresSafeArea())
    }
}

extension View {
    func readableWidth() -> some View {
        modifier(ReadableWidthModifier())
    }
}
