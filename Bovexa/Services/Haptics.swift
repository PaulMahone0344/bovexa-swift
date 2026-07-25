import UIKit

/// Haptics v2 (Liquid Glass restyle): imperatieve haptic-feedback-helper,
/// gebouwd op `UIFeedbackGenerator` in plaats van SwiftUI's
/// `.sensoryFeedback(_:trigger:)`. `.sensoryFeedback` vereist een
/// wisselende `trigger:`-state (bv. een togglende `Bool`/teller) om af te
/// vuren en is daarmee lastig aan te roepen vanuit imperatieve code zoals
/// store-acties of button-handlers zonder per aanroepplek extra trigger-
/// state te moeten beheren. Zie DESIGN-NOTES.md. Nog niet toegepast op
/// bestaande schermen — dat is plak 2-4.
enum Haptics {
    /// Lichte tik voor selectie-wijzigingen (bv. tab-wissel, picker-keuze).
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }

    /// Bevestiging van een geslaagde actie (bv. event opgeslagen).
    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }

    /// Waarschuwing bij een actie die aandacht vraagt (bv. validatiefout).
    static func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
    }
}
