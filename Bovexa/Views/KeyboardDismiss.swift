import SwiftUI

/// "Klaar"-knop boven het toetsenbord, plus wegvegen door te scrollen.
///
/// Meerregelige velden (dagtaak, notities, mededeling, planner) hebben geen
/// return-toets die het toetsenbord sluit — daar maakt Return een nieuwe regel.
/// Zonder deze knop stond je vast: het toetsenbord bleef staan en de knoppen
/// eronder waren niet meer te raken.
struct KeyboardDoneModifier: ViewModifier {
    @FocusState.Binding var focused: Bool

    func body(content: Content) -> some View {
        content
            .focused($focused)
            .toolbar {
                // Alleen aanwezig zolang het veld focus heeft. Zonder die
                // voorwaarde bleef de balk na het sluiten van het toetsenbord
                // achter, onderaan het scherm: over de tabbalk in de Agenda, en
                // over de composer in de Planner.
                if focused {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Klaar") { focused = false }
                            .font(BovexaTheme.TypeStyle.body.weight(.semibold))
                    }
                }
            }
    }
}

extension View {
    /// Zet op een meerregelig tekstveld: geeft het een "Klaar"-knop boven het
    /// toetsenbord.
    func keyboardDone(focused: FocusState<Bool>.Binding) -> some View {
        modifier(KeyboardDoneModifier(focused: focused))
    }
}
