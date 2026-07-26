import Foundation

/// agenda_contacten — privécontacten van de ingelogde gebruiker (m8). Alléén een
/// naam met optioneel telefoon en notitie: geen account, geen melding, geen
/// koppeling met andere gebruikers of bedrijven (valkuil A). Naam "AgendaContact"
/// i.p.v. "Contact" om botsing met Apple's Contacts-framework te vermijden,
/// zelfde reden als "AgendaTask" (m4) en "AgendaLabel" (m7).
struct AgendaContact: Decodable, Identifiable, Equatable {
    let id: String
    let eigenaar: String
    let naam: String
    let telefoon: String
    let notitie: String

    enum CodingKeys: String, CodingKey {
        case id, eigenaar, naam, telefoon, notitie
    }

    init(id: String, eigenaar: String, naam: String, telefoon: String, notitie: String) {
        self.id = id
        self.eigenaar = eigenaar
        self.naam = naam
        self.telefoon = telefoon
        self.notitie = notitie
    }

    /// Defensief decoderen, zelfde stijl als AgendaLabel/AgendaTask: onverwachte of
    /// ontbrekende velden geven een nette fallback in plaats van een crash.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        eigenaar = (try? c.decode(String.self, forKey: .eigenaar)) ?? ""
        naam = (try? c.decode(String.self, forKey: .naam)) ?? ""
        telefoon = (try? c.decode(String.self, forKey: .telefoon)) ?? ""
        notitie = (try? c.decode(String.self, forKey: .notitie)) ?? ""
    }
}
