import Testing
import Foundation
@testable import Bovexa

struct EventRepositoryTests {
    init() {
        URLProtocolStub.requestHandler = nil
    }

    private func makeRepository() -> EventRepository {
        EventRepository(client: PBClient(session: URLProtocolStub.makeSession()))
    }

    private func filterValue(from request: URLRequest) -> String? {
        URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first { $0.name == "filter" }?
            .value
    }

    @Test func fetchAllEventsBuildsFilterWithOrg() async throws {
        URLProtocolStub.requestHandler = { request in
            let filter = self.filterValue(from: request)
            #expect(filter == "(owner = \"u1\" || org = \"org1\" || viewers.id ?= \"u1\")")
            let url = request.url!.absoluteString
            #expect(url.contains("sort=start"))
            let json = """
            {"items":[],"page":1,"perPage":200,"totalItems":0,"totalPages":0}
            """.data(using: .utf8)!
            return (200, json)
        }
        let repo = makeRepository()
        let events = try await repo.fetchAllEvents(userId: "u1", orgId: "org1", token: "tok")
        #expect(events.isEmpty)
    }

    @Test func fetchAllEventsBuildsFilterWithoutOrg() async throws {
        URLProtocolStub.requestHandler = { request in
            let filter = self.filterValue(from: request)
            #expect(filter == "(owner = \"u1\" || viewers.id ?= \"u1\")")
            let json = """
            {"items":[],"page":1,"perPage":200,"totalItems":0,"totalPages":0}
            """.data(using: .utf8)!
            return (200, json)
        }
        let repo = makeRepository()
        _ = try await repo.fetchAllEvents(userId: "u1", orgId: nil, token: "tok")
    }

    @Test func fetchAllEventsAppliesDeclinedFilterAndExpandsRecurrence() async throws {
        URLProtocolStub.requestHandler = { _ in
            let json = """
            {"items":[
              {"id":"a","owner":"collega","title":"Geweigerd","start":"2026-07-24 09:00:00.000Z","all_day":false,"assignee_status":{"u1":"declined"}},
              {"id":"b","owner":"u1","title":"Van mij","start":"2026-07-24 10:00:00.000Z","all_day":false}
            ],"page":1,"perPage":200,"totalItems":2,"totalPages":1}
            """.data(using: .utf8)!
            return (200, json)
        }
        let repo = makeRepository()
        let events = try await repo.fetchAllEvents(userId: "u1", orgId: nil, token: "tok")
        #expect(events.map(\.id) == ["b"])
    }

    @Test func listMembersReturnsNilOnFailureInsteadOfThrowing() async {
        URLProtocolStub.requestHandler = { _ in
            let json = """
            {"data":{},"message":"Geen bedrijf gekoppeld.","status":400}
            """.data(using: .utf8)!
            return (400, json)
        }
        let repo = makeRepository()
        let result = await repo.listMembers(token: "tok")
        #expect(result == nil)
    }

    @Test func listMembersReturnsItemsAndOrgOnSuccess() async {
        URLProtocolStub.requestHandler = { request in
            #expect(request.url!.absoluteString.contains("company/members"))
            let json = """
            {"items":[{"id":"m1","userId":"u1","naam":"Ibrahim","email":"i@bovexa.nl","avatar":""}],
             "org":{"id":"org1","name":"Bovexa","logo":"logo.png"}}
            """.data(using: .utf8)!
            return (200, json)
        }
        let repo = makeRepository()
        let result = await repo.listMembers(token: "tok")
        #expect(result?.items.first?.naam == "Ibrahim")
        #expect(result?.org?.name == "Bovexa")
    }
}
