import Foundation

/// Labels-datalaag (m7): agenda_labels, van het bedrijf en niet van de gebruiker
/// (valkuil G) — iedereen in de org ziet dezelfde lijst en dezelfde kleuren.
final class LabelRepository {
    private let client: PBClient
    private static let collection = "agenda_labels"

    init(client: PBClient = PBClient()) {
        self.client = client
    }

    func fetchLabels(orgId: String, token: String) async throws -> [AgendaLabel] {
        try await client.getFullList(
            AgendaLabel.self, collection: Self.collection, filter: "org = \"\(orgId)\"", sort: "volgorde", token: token
        )
    }

    func createLabel(org: String, naam: String, kleur: String, volgorde: Int, token: String) async throws -> AgendaLabel {
        try await client.createRecord(
            AgendaLabel.self, collection: Self.collection,
            body: ["org": org, "naam": naam, "kleur": kleur, "volgorde": volgorde], token: token
        )
    }

    func renameLabel(id: String, naam: String, token: String) async throws -> AgendaLabel {
        try await client.updateRecord(AgendaLabel.self, collection: Self.collection, id: id, body: ["naam": naam], token: token)
    }

    func updateColor(id: String, kleur: String, token: String) async throws -> AgendaLabel {
        try await client.updateRecord(AgendaLabel.self, collection: Self.collection, id: id, body: ["kleur": kleur], token: token)
    }

    /// Verwijderen mag geen afspraken slopen (valkuil H) — dat gedrag zit in
    /// EventHelpers.eventColor, niet hier: een afspraak met een verwijzing naar
    /// een niet meer bestaand label valt daar netjes terug.
    func deleteLabel(id: String, token: String) async throws {
        try await client.deleteRecord(collection: Self.collection, id: id, token: token)
    }
}
