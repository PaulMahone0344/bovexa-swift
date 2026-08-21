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
    ///
    /// Gaat sinds 21 aug via een route met een echte admin-check op de server.
    /// De deleteRule van de collectie staat nog org-breed open (noodgreep van
    /// 26 juli) en mag pas op null zodra deze versie in de store staat.
    func deleteLabel(id: String, token: String) async throws {
        _ = try await client.postCustom(
            DeleteLabelResponse.self, path: "/api/agenda/labels/delete", body: ["labelId": id], token: token
        )
    }
}

private struct DeleteLabelResponse: Decodable {
    let id: String
}
