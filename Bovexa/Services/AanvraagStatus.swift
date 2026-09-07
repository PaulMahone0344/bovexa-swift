import Foundation

/// De stand van een doorgegeven beschikbaarheid of afwezigheid: de beheerder moet
/// er akkoord op geven, en tot die tijd staat hij op "wacht".
///
/// Leunt op het bestaande `assignee_status` van `agenda_events`, hetzelfde veld dat
/// een gewone toewijzing gebruikt. Daardoor werkt dit zonder serverwijziging: de
/// beheerder krijgt de aanvraag gewoon bij zijn meldingen te zien.
enum AanvraagStand: Equatable {
    case wacht
    case goedgekeurd
    case afgewezen

    var label: String {
        switch self {
        case .wacht: return "Wacht op akkoord"
        case .goedgekeurd: return "Goedgekeurd"
        case .afgewezen: return "Afgewezen"
        }
    }
}

enum AanvraagStatus {
    /// Wat er in het select-veld `goedkeuring` hoort te staan bij een antwoord van
    /// de beheerder. Nil voor een status die geen antwoord is (bijvoorbeeld
    /// "pending"), zodat het veld dan niet aangeraakt wordt.
    static func goedkeuring(voor status: String) -> String? {
        switch status {
        case "accepted": return "akkoord"
        case "declined": return "geweigerd"
        default: return nil
        }
    }

    /// Aanvragen die jij hebt ingediend: jouw blokken met een beheerder eraan
    /// gekoppeld. Nieuwste eerst, en wat allang voorbij is valt weg.
    static func eigenAanvragen(_ events: [AgendaEvent], userId: String, now: Date = Date()) -> [AgendaEvent] {
        let grens = Calendar.current.date(byAdding: .day, value: -14, to: now) ?? now
        return events
            .filter { $0.owner == userId }
            .filter { !$0.assignee.isEmpty }
            .filter { $0.start >= grens }
            .sorted { $0.start < $1.start }
    }

    /// Eén beheerder die "accepted" zei is genoeg; heeft er één geweigerd en niemand
    /// goedgekeurd, dan is het afgewezen. Anders wacht het nog.
    static func stand(_ event: AgendaEvent) -> AanvraagStand {
        let antwoorden = event.assignee.compactMap { event.assigneeStatus[$0] }
        if antwoorden.contains("accepted") { return .goedgekeurd }
        if !antwoorden.isEmpty, antwoorden.allSatisfy({ $0 == "declined" }) { return .afgewezen }
        return .wacht
    }
}
