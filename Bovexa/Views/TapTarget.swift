import SwiftUI

/// Raakvlak-helpers voor knoppen (M11, patroon B). Apple's richtlijn is 44×44pt;
/// de app zat vol doelen van 15-26pt — kleurbolletjes, chevrons, sterren,
/// prullenbakken, tekstknoppen in footnote.
///
/// Twee regels die uit de bugronde van 26 juli komen en hier weer gelden:
///  1. ALTIJD ín de label-closure van een Button gebruiken, nooit op de Button
///     zelf. `contentShape` op de Button doet niets voor hit-testing.
///  2. De tekening blijft even groot — alleen het raakvlak groeit. Zet het
///     icoon/bolletje eerst op zijn eigen maat, dán deze helper.
extension View {
    /// Minimaal `size`×`size` raakvlak zonder de tekening te vergroten.
    func minTapTarget(_ size: CGFloat = 44) -> some View {
        frame(minWidth: size, minHeight: size)
            .contentShape(Rectangle())
    }

    /// Voor rijen die over de volle breedte moeten raken (naam hernoemen, een
    /// ledenrij, een uitklapkop). Links uitgelijnd, want dat is wat een rij doet.
    func rowTapTarget(minHeight: CGFloat = 44) -> some View {
        frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
            .contentShape(Rectangle())
    }
}
