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

    /// URLSession verplaatst httpBody vaak stilletjes naar httpBodyStream vóórdat een
    /// URLProtocol-subclass het verzoek ziet — request.httpBody is dan nil.
    private func bodyData(from request: URLRequest) -> Data {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: buffer.count)
            guard read > 0 else { break }
            data.append(buffer, count: read)
        }
        return data
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

    @Test func fetchOwnEventsFiltersToOwnerAndExpandsRecurrence() async throws {
        URLProtocolStub.requestHandler = { request in
            let filter = self.filterValue(from: request)
            #expect(filter == "owner = \"u1\"")
            let json = """
            {"items":[{"id":"a","owner":"u1","title":"Eigen","start":"2026-08-03 09:00:00.000Z","all_day":false}],
             "page":1,"perPage":200,"totalItems":1,"totalPages":1}
            """.data(using: .utf8)!
            return (200, json)
        }
        let repo = makeRepository()
        let events = try await repo.fetchOwnEvents(userId: "u1", token: "tok")
        #expect(events.map(\.id) == ["a"])
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

    // MARK: - updateEvent (valkuil E)

    @Test func updateEventSendsPatchToRecordIdWithPayloadBody() async throws {
        URLProtocolStub.requestHandler = { request in
            #expect(request.httpMethod == "PATCH")
            #expect(request.url!.absoluteString.contains("/api/collections/agenda_events/records/rec1"))
            let body = try! JSONSerialization.jsonObject(with: self.bodyData(from: request)) as! [String: Any]
            #expect(body["title"] as? String == "Nieuwe titel")
            #expect(body["source"] == nil)
            let json = """
            {"id":"rec1","owner":"u1","title":"Nieuwe titel","start":"2026-08-03 09:00:00.000Z","all_day":false}
            """.data(using: .utf8)!
            return (200, json)
        }
        let repo = makeRepository()
        let payload = EventUpdatePayload(
            title: "Nieuwe titel", category: .work, start: Date(), end: Date(),
            notes: "", klantNaam: "", klantTelefoon: "", reminders: [],
            assignee: [], viewers: [], assigneeStatus: [:]
        )
        let updated = try await repo.updateEvent(recordId: "rec1", payload: payload, token: "tok")
        #expect(updated.title == "Nieuwe titel")
    }

    // MARK: - deleteEvent

    @Test func deleteEventSendsDeleteToRecordId() async throws {
        URLProtocolStub.requestHandler = { request in
            #expect(request.httpMethod == "DELETE")
            #expect(request.url!.absoluteString.contains("/api/collections/agenda_events/records/rec1"))
            return (204, Data())
        }
        let repo = makeRepository()
        try await repo.deleteEvent(recordId: "rec1", token: "tok")
    }

    // MARK: - updateVisibility (valkuil C — union met assignees)

    @Test func updateVisibilitySendsUnionOfViewersAndAssignees() async throws {
        URLProtocolStub.requestHandler = { request in
            #expect(request.httpMethod == "PATCH")
            let body = try! JSONSerialization.jsonObject(with: self.bodyData(from: request)) as! [String: Any]
            #expect(body["visibility"] as? String == "company")
            #expect(body["viewers"] as? [String] == ["u2"])
            let json = """
            {"id":"rec1","owner":"u1","title":"T","start":"2026-08-03 09:00:00.000Z","all_day":false}
            """.data(using: .utf8)!
            return (200, json)
        }
        let repo = makeRepository()
        _ = try await repo.updateVisibility(recordId: "rec1", visibility: "company", viewers: [], assignees: ["u2"], token: "tok")
    }

    // MARK: - respondToAssignment (valkuil B + A — eigen sleutel, echte record-id)

    @Test func respondToAssignmentWritesOwnKeyToRealRecordIdOfExpandedOccurrence() async throws {
        URLProtocolStub.requestHandler = { request in
            #expect(request.url!.absoluteString.contains("/api/collections/agenda_events/records/rec1"))
            let body = try! JSONSerialization.jsonObject(with: self.bodyData(from: request)) as! [String: Any]
            let statusMap = body["assignee_status"] as! [String: String]
            #expect(statusMap == ["u1": "accepted", "u2": "declined"])
            let json = """
            {"id":"rec1","owner":"owner","title":"T","start":"2026-08-03 09:00:00.000Z","all_day":false}
            """.data(using: .utf8)!
            return (200, json)
        }
        let repo = makeRepository()
        let occurrence = AgendaEvent(
            id: "rec1:2026-08-03", owner: "owner", calendar: nil, category: nil, title: "T",
            start: Date(), end: nil, allDay: false, recurrence: nil, location: nil, notes: nil,
            klantNaam: nil, assigneeStatus: ["u2": "declined"], seriesId: "rec1", occurrenceDate: "2026-08-03"
        )
        _ = try await repo.respondToAssignment(event: occurrence, userId: "u1", status: "accepted", token: "tok")
    }
}
