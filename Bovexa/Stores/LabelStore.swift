import SwiftUI

/// Cache van de labellijst voor het huidige bedrijf, naar het voorbeeld van
/// `MemberColors`: laadt één keer via `prime`, geeft daarna lookups terug —
/// nil bij een onbekend of verwijderd label (valkuil H), nooit een crash.
final class LabelStore: ObservableObject {
    @Published private(set) var orderedLabels: [AgendaLabel] = []

    private var labelMap: [String: AgendaLabel] = [:]

    func prime(labels: [AgendaLabel]) {
        orderedLabels = labels.sorted { $0.volgorde < $1.volgorde }
        labelMap = Dictionary(uniqueKeysWithValues: labels.map { ($0.id, $0) })
    }

    /// Voegt een nieuw label toe zonder opnieuw te laden — voor "Nieuw label"
    /// in de labelkiezer (m7 plak 3), meteen bruikbaar zonder scherm-refresh.
    func add(_ label: AgendaLabel) {
        labelMap[label.id] = label
        orderedLabels = (orderedLabels + [label]).sorted { $0.volgorde < $1.volgorde }
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
