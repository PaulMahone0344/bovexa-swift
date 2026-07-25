import Foundation

/// Mededelingen-datalaag: lezen rechtstreeks op agenda_notices (listRule filtert al
/// op eigen org), plaatsen via de server-route (rol-check, valkuil D), verwijderen
/// rechtstreeks (collection-rule staat alleen de schrijver toe).
final class NoticeRepository {
    private let client: PBClient

    init(client: PBClient = PBClient()) {
        self.client = client
    }

    private static let collection = "agenda_notices"

    func fetchNotices(orgId: String, token: String) async throws -> [Notice] {
        try await client.getFullList(
            Notice.self, collection: Self.collection, filter: "org = \"\(orgId)\"", sort: "-created", token: token
        )
    }

    func createNotice(title: String, body: String, token: String) async throws -> Notice {
        try await client.postCustom(Notice.self, path: "/api/agenda/notices/create", body: ["title": title, "body": body], token: token)
    }

    func deleteNotice(id: String, token: String) async throws {
        try await client.deleteRecord(collection: Self.collection, id: id, token: token)
    }
}
