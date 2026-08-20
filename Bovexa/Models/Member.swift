/// Response van POST /api/agenda/company/members — alleen velden die de Agenda
/// gebruikt (persoonskleuren, voornaam-labels, logo-banner op Vandaag, en sinds
/// m10 het recht om de agenda van collega's te bekijken).
///
/// Dezelfde route levert via `CompanyMembersResponse` het volledige lid met alle
/// rechten. Die twee zijn bewust gescheiden: de Agenda heeft de hele rechtenset
/// niet nodig. `role` en `magAgendaAnderenZien` staan er nu wél bij, zodat het
/// personenfilter geen tweede verzoek hoeft te doen voor iets dat al meekomt.
struct Member: Decodable, Equatable {
    let id: String
    let userId: String
    let naam: String
    let email: String
    let avatar: String
    let role: CompanyRole?
    let magAgendaAnderenZien: Bool

    enum CodingKeys: String, CodingKey {
        case id, userId, naam, email, avatar, role
        case magAgendaAnderenZien = "mag_agenda_anderen_zien"
    }

    init(
        id: String, userId: String, naam: String, email: String, avatar: String,
        role: CompanyRole? = nil, magAgendaAnderenZien: Bool = false
    ) {
        self.id = id
        self.userId = userId
        self.naam = naam
        self.email = email
        self.avatar = avatar
        self.role = role
        self.magAgendaAnderenZien = magAgendaAnderenZien
    }

    /// Defensief, zelfde stijl als AgendaLabel/AgendaEvent: de twee nieuwe velden
    /// mogen ontbreken zonder dat de hele ledenlijst wegvalt. Ontbreken betekent
    /// "geen recht" — liever een knop te weinig dan een lijst met namen die je
    /// daarna niet kunt openen.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        userId = (try? c.decode(String.self, forKey: .userId)) ?? ""
        naam = (try? c.decode(String.self, forKey: .naam)) ?? ""
        email = (try? c.decode(String.self, forKey: .email)) ?? ""
        avatar = (try? c.decode(String.self, forKey: .avatar)) ?? ""
        role = try? c.decode(CompanyRole.self, forKey: .role)
        magAgendaAnderenZien = ((try? c.decodeIfPresent(Bool.self, forKey: .magAgendaAnderenZien)) ?? nil) ?? false
    }
}

struct CompanyOrgInfo: Decodable, Equatable {
    let id: String
    let name: String
    let logo: String
    /// Standaardduur van een afspraak in minuten (M12): dezelfde route stuurt dit
    /// al mee in het volledige `CompanyOrgProfile`, dus het handmatige formulier
    /// hoeft er geen tweede verzoek voor te doen. Ontbreekt of 0 ⇒ nil, en dan
    /// gebruikt het formulier zijn eigen terugval.
    let defaultDurationMin: Int?

    enum CodingKeys: String, CodingKey {
        case id, name, logo
        case defaultDurationMin = "default_duration_min"
    }

    init(id: String, name: String, logo: String, defaultDurationMin: Int? = nil) {
        self.id = id
        self.name = name
        self.logo = logo
        self.defaultDurationMin = defaultDurationMin
    }

    /// Defensief, zelfde lijn als Member/AgendaEvent: een ontbrekende of anders
    /// getypeerde duur mag de hele ledenlijst niet laten omvallen — daar hangen de
    /// persoonskleuren en de bedrijfsnaam aan.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        logo = (try? c.decode(String.self, forKey: .logo)) ?? ""
        defaultDurationMin = ((try? c.decodeIfPresent(Int.self, forKey: .defaultDurationMin)) ?? nil)
    }
}

struct MembersResponse: Decodable {
    let items: [Member]
    let org: CompanyOrgInfo?
}
