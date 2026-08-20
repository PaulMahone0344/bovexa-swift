import SwiftUI

/// Cache van de labellijst voor het huidige bedrijf, naar het voorbeeld van
/// `MemberColors`: laadt één keer via `prime`, geeft daarna lookups terug —
/// nil bij een onbekend of verwijderd label (valkuil H), nooit een crash.
final class LabelStore: ObservableObject {
    @Published private(set) var orderedLabels: [AgendaLabel] = []

    private var labelMap: [String: AgendaLabel] = [:]

    func prime(labels: [AgendaLabel]) {
        orderedLabels = labels.sorted { $0.volgorde < $1.volgorde }
        // `uniqueKeysWithValues` crasht op een dubbel id — mogelijk bij een
        // gepagineerde getFullList terwijl een collega tussendoor invoegt.
        labelMap = Dictionary(labels.map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
    }

    /// Voegt een nieuw label toe zonder opnieuw te laden — voor "Nieuw label"
    /// in de labelkiezer (m7 plak 3), meteen bruikbaar zonder scherm-refresh.
    func add(_ label: AgendaLabel) {
        labelMap[label.id] = label
        orderedLabels = (orderedLabels + [label]).sorted { $0.volgorde < $1.volgorde }
    }

    /// Vervangt een bestaand label — voor hernoemen/kleur-wijzigen vanuit de
    /// legenda (m7 plak 6), wijzigt meteen overal waar dat label gebruikt wordt.
    func update(_ label: AgendaLabel) {
        labelMap[label.id] = label
        orderedLabels = orderedLabels.map { $0.id == label.id ? label : $0 }
    }

    /// Verwijderen slaat afspraken met dat label niet stuk (valkuil H) — die
    /// vallen terug op categoriekleur via EventHelpers.eventColor omdat het label
    /// hier niet meer te vinden is.
    func remove(id: String) {
        labelMap[id] = nil
        orderedLabels = orderedLabels.filter { $0.id != id }
    }

    func label(for id: String?) -> AgendaLabel? {
        guard let id else { return nil }
        return labelMap[id]
    }

    func color(for id: String?) -> Color? {
        guard let label = label(for: id) else { return nil }
        return Color(hex: label.kleur)
    }
}
