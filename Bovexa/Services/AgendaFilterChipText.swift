import Foundation

/// Tekst op de chip boven de Agenda die vertelt dat je meer ziet dan je eigen dag.
///
/// Zonder dat teken lijkt een raster met veel afspraken gewoon "de agenda", en is
/// niet te zien van wie al die blokken zijn. Bij één of twee collega's staan de
/// namen er zelf, daarna wordt de chip te breed voor een telefoon en telt hij.
enum AgendaFilterChipText {
    static func text(extraNames: [String]) -> String? {
        let names = extraNames.filter { !$0.isEmpty }.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        switch names.count {
        case 0: return nil
        case 1: return "Jij + \(names[0])"
        case 2: return "Jij + \(names[0]) en \(names[1])"
        default: return "Jij + \(names.count) collega's"
        }
    }
}
