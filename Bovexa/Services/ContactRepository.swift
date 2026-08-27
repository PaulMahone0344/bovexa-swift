import Foundation

/// Contacten-datalaag (m8): agenda_contacten, van de gebruiker en niet van het
/// bedrijf (valkuil A) — elke gebruiker ziet alleen zijn eigen lijst.
final class ContactRepository {
    private let client: PBClient
    private static let collection = "agenda_contacten"

    init(client: PBClient = PBClient()) {
        self.client = client
    }

    func fetchContacts(userId: String, token: String) async throws -> [AgendaContact] {
        try await client.getFullList(
            AgendaContact.self, collection: Self.collection, filter: "eigenaar = \"\(userId)\"", sort: "naam", token: token
        )
    }

    /// `org` leeg (of nil) maakt een privécontact; een org-id maakt een contact van
    /// dat bedrijf. Het veld `org` moet daarvoor wel op `agenda_contacten` bestaan —
    /// zie MEERDERE-BEDRIJVEN-SERVER.txt.
    func createContact(eigenaar: String, naam: String, telefoon: String, notitie: String, org: String? = nil, token: String) async throws -> AgendaContact {
        var body: [String: Any] = ["eigenaar": eigenaar, "naam": naam, "telefoon": telefoon, "notitie": notitie]
        if let org, !org.isEmpty { body["org"] = org }
        return try await client.createRecord(AgendaContact.self, collection: Self.collection, body: body, token: token)
    }

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
