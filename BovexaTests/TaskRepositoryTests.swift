import Testing
import Foundation
@testable import Bovexa

struct TaskRepositoryTests {
    init() {
        URLProtocolStub.requestHandler = nil
    }

    private func makeRepository() -> TaskRepository {
        TaskRepository(client: PBClient(session: URLProtocolStub.makeSession()))
    }

    private func queryValue(_ name: String, from request: URLRequest) -> String? {
        URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first { $0.name == name }?
            .value
    }

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

    // MARK: - fetchTasks

    @Test func fetchTasksSortsByCreatedDescendingAndExpandsOwner() async throws {
        URLProtocolStub.requestHandler = { request in
            #expect(self.queryValue("sort", from: request) == "-created")
            #expect(self.queryValue("expand", from: request) == "owner")
            let json = """
            {"items":[],"page":1,"perPage":200,"totalItems":0,"totalPages":0}
            """.data(using: .utf8)!
            return (200, json)
        }
        let repo = makeRepository()
        let tasks = try await repo.fetchTasks(token: "tok")
        #expect(tasks.isEmpty)
    }

    @Test func fetchTasksDecodesOwnerNameFromExpand() async throws {
        URLProtocolStub.requestHandler = { _ in
            let json = """
            {"items":[
              {"id":"t1","owner":"u2","org":"org1","title":"Voorraad tellen","notes":"","status":"open",
               "visibility":"company","viewers":[],"created":"2026-07-24 09:00:00.000Z","updated":"2026-07-24 09:00:00.000Z",
               "expand":{"owner":{"id":"u2","email":"collega@bovexa.nl","naam":"Karim","avatar":"","default_org":"org1"}}}
            ],"page":1,"perPage":200,"totalItems":1,"totalPages":1}
            """.data(using: .utf8)!
            return (200, json)
        }
        let repo = makeRepository()
        let tasks = try await repo.fetchTasks(token: "tok")
        #expect(tasks.first?.expand?.owner?.naam == "Karim")
        #expect(tasks.first?.status == .open)
        #expect(tasks.first?.visibility == .company)
    }

    // MARK: - createTask (visibility-terugval)

    @Test func createTaskWithOrgFallsBackToCompanyVisibility() async throws {
        URLProtocolStub.requestHandler = { request in
            let body = try! JSONSerialization.jsonObject(with: self.bodyData(from: request)) as! [String: Any]
            #expect(body["org"] as? String == "org1")
            #expect(body["visibility"] as? String == "company")
            #expect(body["viewers"] as? [String] == [])
            let json = """
            {"id":"t1","owner":"u1","org":"org1","title":"Nieuwe taak","notes":"","status":"open",
             "visibility":"company","viewers":[],"created":"2026-07-24 09:00:00.000Z","updated":"2026-07-24 09:00:00.000Z"}
            """.data(using: .utf8)!
            return (200, json)
        }
        let repo = makeRepository()
        _ = try await repo.createTask(owner: "u1", org: "org1", title: "Nieuwe taak", token: "tok")
    }

    @Test func createTaskWithoutOrgFallsBackToPrivateVisibility() async throws {
        URLProtocolStub.requestHandler = { request in
            let body = try! JSONSerialization.jsonObject(with: self.bodyData(from: request)) as! [String: Any]
            #expect(body["org"] as? String == "")
            #expect(body["visibility"] as? String == "private")
            let json = """
            {"id":"t1","owner":"u1","org":"","title":"Nieuwe taak","notes":"","status":"open",
             "visibility":"private","viewers":[],"created":"2026-07-24 09:00:00.000Z","updated":"2026-07-24 09:00:00.000Z"}
            """.data(using: .utf8)!
            return (200, json)
        }
        let repo = makeRepository()
        _ = try await repo.createTask(owner: "u1", org: nil, title: "Nieuwe taak", token: "tok")
    }

    @Test func createTaskWithEmptyOrgStringDoesNotWriteCompany() async throws {
        URLProtocolStub.requestHandler = { request in
            let body = try! JSONSerialization.jsonObject(with: self.bodyData(from: request)) as! [String: Any]
            #expect(body["org"] as? String == "")
            #expect(body["visibility"] as? String != "company")
            let json = """
            {"id":"t1","owner":"u1","org":"","title":"Taak","notes":"","status":"open",
             "visibility":"private","viewers":[],"created":"2026-07-24 09:00:00.000Z","updated":"2026-07-24 09:00:00.000Z"}
            """.data(using: .utf8)!
            return (200, json)
        }
        let repo = makeRepository()
        _ = try await repo.createTask(owner: "u1", org: "", title: "Taak", token: "tok")
    }

    @Test func createTaskWithPeopleVisibilityIncludesViewers() async throws {
        URLProtocolStub.requestHandler = { request in
            let body = try! JSONSerialization.jsonObject(with: self.bodyData(from: request)) as! [String: Any]
            #expect(body["visibility"] as? String == "people")
            #expect(body["viewers"] as? [String] == ["u2", "u3"])
            let json = """
            {"id":"t1","owner":"u1","org":"org1","title":"Taak","notes":"","status":"open",
             "visibility":"people","viewers":["u2","u3"],"created":"2026-07-24 09:00:00.000Z","updated":"2026-07-24 09:00:00.000Z"}
            """.data(using: .utf8)!
            return (200, json)
        }
        let repo = makeRepository()
        _ = try await repo.createTask(owner: "u1", org: "org1", title: "Taak", visibility: .people, viewers: ["u2", "u3"], token: "tok")
    }

    @Test func createTaskWithExplicitPrivateVisibilityDropsViewersEvenWithOrg() async throws {
        URLProtocolStub.requestHandler = { request in
            let body = try! JSONSerialization.jsonObject(with: self.bodyData(from: request)) as! [String: Any]
            #expect(body["visibility"] as? String == "private")
            #expect(body["viewers"] as? [String] == [])
            let json = """
            {"id":"t1","owner":"u1","org":"org1","title":"Taak","notes":"","status":"open",
             "visibility":"private","viewers":[],"created":"2026-07-24 09:00:00.000Z","updated":"2026-07-24 09:00:00.000Z"}
            """.data(using: .utf8)!
            return (200, json)
        }
        let repo = makeRepository()
        _ = try await repo.createTask(owner: "u1", org: "org1", title: "Taak", visibility: .private, viewers: ["u2"], token: "tok")
    }

    @Test func createTaskTrimsTitleAndNotes() async throws {
        URLProtocolStub.requestHandler = { request in
            let body = try! JSONSerialization.jsonObject(with: self.bodyData(from: request)) as! [String: Any]
            #expect(body["title"] as? String == "Taak")
            #expect(body["notes"] as? String == "Extra tekst")
            let json = """
            {"id":"t1","owner":"u1","org":"","title":"Taak","notes":"Extra tekst","status":"open",
             "visibility":"private","viewers":[],"created":"2026-07-24 09:00:00.000Z","updated":"2026-07-24 09:00:00.000Z"}
            """.data(using: .utf8)!
            return (200, json)
        }
        let repo = makeRepository()
        _ = try await repo.createTask(owner: "u1", org: nil, title: "  Taak  ", notes: "  Extra tekst  ", token: "tok")
    }

    // MARK: - setStatus

    @Test func setStatusSendsPatchWithNewStatus() async throws {
        URLProtocolStub.requestHandler = { request in
            #expect(request.httpMethod == "PATCH")
            #expect(request.url!.absoluteString.contains("/api/collections/agenda_tasks/records/t1"))
            let body = try! JSONSerialization.jsonObject(with: self.bodyData(from: request)) as! [String: Any]
            #expect(body["status"] as? String == "klaar")
            let json = """
            {"id":"t1","owner":"u1","org":"","title":"Taak","notes":"","status":"klaar",
             "visibility":"private","viewers":[],"created":"2026-07-24 09:00:00.000Z","updated":"2026-07-24 09:00:00.000Z"}
            """.data(using: .utf8)!
            return (200, json)
        }
        let repo = makeRepository()
        let updated = try await repo.setStatus(id: "t1", status: .klaar, token: "tok")
        #expect(updated.status == .klaar)
    }

    @Test func setStatusWithCompletedAtSendsFormattedDate() async throws {
        let completedAt = Date(timeIntervalSince1970: 1_753_000_000)
        URLProtocolStub.requestHandler = { request in
            let body = try! JSONSerialization.jsonObject(with: self.bodyData(from: request)) as! [String: Any]
            #expect(body["completed_at"] as? String == PBDate.format(completedAt))
            let json = """
            {"id":"t1","owner":"u1","org":"","title":"Taak","notes":"","status":"klaar","completed_at":"\(PBDate.format(completedAt))",
             "visibility":"private","viewers":[],"created":"2026-07-24 09:00:00.000Z","updated":"2026-07-24 09:00:00.000Z"}
            """.data(using: .utf8)!
            return (200, json)
        }
        let repo = makeRepository()
        let updated = try await repo.setStatus(id: "t1", status: .klaar, completedAt: completedAt, token: "tok")
        #expect(updated.completedAt != nil)
    }

    @Test func setStatusWithoutCompletedAtSendsNullToClearIt() async throws {
        URLProtocolStub.requestHandler = { request in
            let body = try! JSONSerialization.jsonObject(with: self.bodyData(from: request)) as! [String: Any]
            #expect(body["completed_at"] is NSNull)
            let json = """
            {"id":"t1","owner":"u1","org":"","title":"Taak","notes":"","status":"open",
             "visibility":"private","viewers":[],"created":"2026-07-24 09:00:00.000Z","updated":"2026-07-24 09:00:00.000Z"}
            """.data(using: .utf8)!
            return (200, json)
        }
        let repo = makeRepository()
        _ = try await repo.setStatus(id: "t1", status: .open, token: "tok")
    }

    /// Bij een taak voor het hele team is `completed_by` het enige spoor van wie
    /// hem afvinkte.
    @Test func setStatusStuurtCompletedByMee() async throws {
        URLProtocolStub.requestHandler = { request in
            let body = try! JSONSerialization.jsonObject(with: self.bodyData(from: request)) as! [String: Any]
            #expect(body["completed_by"] as? String == "u1")
            let json = """
            {"id":"t1","owner":"u1","org":"","title":"Taak","notes":"","status":"klaar","completed_by":"u1",
             "visibility":"company","viewers":[],"created":"2026-07-24 09:00:00.000Z","updated":"2026-07-24 09:00:00.000Z"}
            """.data(using: .utf8)!
            return (200, json)
        }
        let repo = makeRepository()
        let updated = try await repo.setStatus(id: "t1", status: .klaar, completedAt: Date(), completedBy: "u1", token: "tok")
        #expect(updated.completedBy == "u1")
    }

    /// Een relatie wist PocketBase met een lege tekst, niet met null.
    @Test func setStatusZonderCompletedByStuurtLegeTekstOmTeWissen() async throws {
        URLProtocolStub.requestHandler = { request in
            let body = try! JSONSerialization.jsonObject(with: self.bodyData(from: request)) as! [String: Any]
            #expect(body["completed_by"] as? String == "")
            let json = """
            {"id":"t1","owner":"u1","org":"","title":"Taak","notes":"","status":"open","completed_by":"",
             "visibility":"company","viewers":[],"created":"2026-07-24 09:00:00.000Z","updated":"2026-07-24 09:00:00.000Z"}
            """.data(using: .utf8)!
            return (200, json)
        }
        let repo = makeRepository()
        let updated = try await repo.setStatus(id: "t1", status: .open, token: "tok")
        #expect(updated.completedBy == nil)
    }

    // MARK: - deleteTask

    @Test func deleteTaskSendsDeleteToRecordId() async throws {
        URLProtocolStub.requestHandler = { request in
            #expect(request.httpMethod == "DELETE")
            #expect(request.url!.absoluteString.contains("/api/collections/agenda_tasks/records/t1"))
            return (204, Data())
        }
        let repo = makeRepository()
        try await repo.deleteTask(id: "t1", token: "tok")
    }
}
