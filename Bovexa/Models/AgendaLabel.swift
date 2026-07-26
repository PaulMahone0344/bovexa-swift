import Foundation

/// agenda_labels — door de gebruiker beheerde lijst van benoemde, gekleurde labels
/// per bedrijf (m7). Naam "AgendaLabel" i.p.v. "Label" om botsing met SwiftUI's
/// eigen `Label`-view te vermijden (zelfde reden als "AgendaTask" i.p.v. "Task").
struct AgendaLabel: Decodable, Identifiable, Equatable {
    let id: String
    let org: String
    let naam: String
    let kleur: String
    let volgorde: Int

    enum CodingKeys: String, CodingKey {
        case id, org, naam, kleur, volgorde
    }

    init(id: String, org: String, naam: String, kleur: String, volgorde: Int) {
        self.id = id
        self.org = org
        self.naam = naam
        self.kleur = kleur
        self.volgorde = volgorde
    }

    /// Defensief decoderen, zelfde stijl als AgendaTask/AgendaEvent: onverwachte of
    /// ontbrekende velden geven een nette fallback in plaats van een crash.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        org = (try? c.decode(String.self, forKey: .org)) ?? ""
        naam = (try? c.decode(String.self, forKey: .naam)) ?? ""
        kleur = (try? c.decode(String.self, forKey: .kleur)) ?? ""
        volgorde = ((try? c.decodeIfPresent(Int.self, forKey: .volgorde)) ?? nil) ?? 0
    }
}
