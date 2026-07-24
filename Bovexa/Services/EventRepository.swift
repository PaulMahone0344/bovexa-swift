import Foundation

/// Events-datalaag: filterbouw, declined-filter, herhalingen uitklappen, ledenlijst.
final class EventRepository {
    private let client: PBClient

    init(client: PBClient = PBClient()) {
        self.client = client
    }

    func fetchAllEvents(userId: String, orgId: String?, token: String) async throws -> [AgendaEvent] {
        let filter: String
        if let orgId {
            filter = "(owner = \"\(userId)\" || org = \"\(orgId)\" || viewers.id ?= \"\(userId)\")"
        } else {
            filter = "(owner = \"\(userId)\" || viewers.id ?= \"\(userId)\")"
        }

        let items = try await client.getFullList(
            AgendaEvent.self, collection: "agenda_events", filter: filter, sort: "start", token: token
        )
        return RecurrenceExpander.expand(items.excludingDeclined(for: userId))
    }

    /// Faalt stil (geen bedrijf gekoppeld, netwerkfout, ...) — dan gewoon geen kleuren/logo.
    func listMembers(token: String) async -> MembersResponse? {
        try? await client.postCustom(MembersResponse.self, path: "/api/agenda/company/members", token: token)
    }
}
