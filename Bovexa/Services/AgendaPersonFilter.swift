import Foundation

/// Filtert de Agenda op de mensen die je hebt aangevinkt (m10, omgedraaid op
/// 26 juli).
///
/// Tot dan begon de Agenda op "iedereen" en koos je één collega. Met twaalf leden
/// betekende dat: app openen en meteen de agenda van het hele bedrijf in één
/// raster. Nu is je eigen agenda het startpunt en vink je collega's erbij.
///
/// "De agenda van persoon P" is alles wat P bezit óf wat aan P is toegewezen. Dat
/// tweede deel is geen detail: een afspraak die de baas aanmaakt en aan Daan
/// toewijst is Daans dag, en zonder die regel mist een medewerker precies het werk
/// dat hij moet doen.
///
/// De definitie staat hier op één plek zodat elke weergave — maand, gestapeld,
/// details, lijst, dagweergave, dagsheet — hetzelfde antwoord geeft.
enum AgendaPersonFilter {
    static func matches(_ event: AgendaEvent, userIds: Set<String>) -> Bool {
        // Externe afspraken komen van het toestel van de ingelogde gebruiker en
        // hebben geen eigenaar. Ze horen bij niemand in het bedrijf, maar wél bij
        // jou — en jouw eigen agenda staat altijd aan, dus ze blijven staan.
        if event.isExternal { return true }
        // Een lege selectie hoort niet voor te komen: je eigen agenda staat vast
        // aan. Gebeurt het toch, dan liever alles tonen dan een leeg raster zonder
        // enige uitleg.
        guard !userIds.isEmpty else { return true }
        return userIds.contains(event.owner) || !userIds.isDisjoint(with: event.assignee)
    }

    static func apply(_ events: [AgendaEvent], userIds: Set<String>) -> [AgendaEvent] {
        events.filter { matches($0, userIds: userIds) }
    }
}
