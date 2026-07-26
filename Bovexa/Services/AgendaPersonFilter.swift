import Foundation

/// Filtert de Agenda op één persoon (m10).
///
/// "De agenda van persoon P" is alles wat P bezit óf wat aan P is toegewezen. Dat
/// tweede deel is geen detail: een afspraak die de baas aanmaakt en aan Daan
/// toewijst is Daans dag, en zonder die regel mist een medewerker precies het werk
/// dat hij moet doen.
///
/// De definitie staat hier op één plek zodat elke weergave — maand, gestapeld,
/// details, lijst, dagweergave, dagsheet — hetzelfde antwoord geeft.
enum AgendaPersonFilter {
    /// `userId == nil` betekent "iedereen" en laat alles door.
    static func matches(_ event: AgendaEvent, userId: String?) -> Bool {
        guard let userId else { return true }
        // Externe afspraken komen van het toestel van de ingelogde gebruiker en
        // hebben geen eigenaar; die horen bij niemand in het bedrijf.
        guard !event.isExternal else { return false }
        return event.owner == userId || event.assignee.contains(userId)
    }

    static func apply(_ events: [AgendaEvent], userId: String?) -> [AgendaEvent] {
        guard let userId else { return events }
        return events.filter { matches($0, userId: userId) }
    }
}
