import Foundation

/// Contacten-datalaag (m8): agenda_contacten. Een contact zonder `org` is privé en
/// alleen van de eigenaar; een contact mét `org` hoort bij dat bedrijf en is voor
/// alle leden daarvan zichtbaar. Sinds 7 september staat `org` op de server en
/// leest de leesregel mee met `default_org`, dus de indeling komt niet langer van
/// het toestel maar uit het record zelf.
final class ContactRepository {
    private let client: PBClient
    private static let collection = "agenda_contacten"

    init(client: PBClient = PBClient()) {
        self.client = client
    }

    /// `defaultOrg` is het bedrijf van de ingelogde gebruiker. Leeg (geen bedrijf)
    /// levert alleen de eigen contacten op; gevuld haalt ook de bedrijfscontacten
    /// van collega's op — precies wat de leesregel op de server toelaat, zodat de
    /// app niet om records vraagt die hij toch niet terugkrijgt.
    func fetchContacts(userId: String, defaultOrg: String = "", token: String) async throws -> [AgendaContact] {
        var filter = "eigenaar = \"\(userId)\""
        if !defaultOrg.isEmpty {
            filter += " || org = \"\(defaultOrg)\""
        }
        return try await client.getFullList(
            AgendaContact.self, collection: Self.collection, filter: filter, sort: "naam", token: token
        )
    }

    /// `org` leeg (of nil) maakt een privécontact; een org-id maakt een contact van
    /// dat bedrijf.
    func createContact(eigenaar: String, naam: String, telefoon: String, notitie: String, org: String? = nil, token: String) async throws -> AgendaContact {
        var body: [String: Any] = ["eigenaar": eigenaar, "naam": naam, "telefoon": telefoon, "notitie": notitie]
        if let org, !org.isEmpty { body["org"] = org }
        return try await client.createRecord(AgendaContact.self, collection: Self.collection, body: body, token: token)
    }

    /// `org` staat bewust niet in de payload: wijzigen gaat over naam, telefoon en
    /// notitie. Zou het veld meegestuurd worden, dan zou een leeg veld een
    /// bedrijfscontact stilletjes naar Privé verhuizen — en daarmee uit het zicht
    /// van de collega's die hem wél mogen zien.
    func updateContact(id: String, naam: String, telefoon: String, notitie: String, token: String) async throws -> AgendaContact {
        try await client.updateRecord(
            AgendaContact.self, collection: Self.collection, id: id,
            body: ["naam": naam, "telefoon": telefoon, "notitie": notitie], token: token
        )
    }

    func deleteContact(id: String, token: String) async throws {
        try await client.deleteRecord(collection: Self.collection, id: id, token: token)
    }
}
