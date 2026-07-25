import Foundation

/// Klantenlijst (afgeleid uit klant_naam/klant_telefoon op agenda_events, valkuil F
/// — geen eigen klanten-collectie). Geport uit KlantGroup/groupByKlant in
/// ~/Desktop/agenda-app/src/lib/events.ts.
struct KlantGroup: Identifiable, Equatable {
    let naam: String
    let telefoon: String?
    /// Oplopend op start.
    let events: [AgendaEvent]

    var id: String { naam.lowercased() }
}
