import Testing
import Foundation
@testable import Bovexa

struct ContactRepositoryTests {
    init() {
        URLProtocolStub.requestHandler = nil
    }

    private func makeRepository() -> ContactRepository {
        ContactRepository(client: PBClient(session: URLProtocolStub.makeSession()))
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

    // MARK: - fetchContacts

    @Test func fetchContactsFiltersOnEigenaarAndSortsByNaam() async throws {
        URLProtocolStub.requestHandler = { request in
            let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
            #expect(components.queryItems?.first { $0.name == "filter" }?.value == "eigenaar = \"u1\"")
            #expect(components.queryItems?.first { $0.name == "sort" }?.value == "naam")
            let json = """
            {"items":[{"id":"c1","eigenaar":"u1","naam":"Karim","telefoon":"","notitie":""}],
             "page":1,"perPage":200,"totalItems":1,"totalPages":1}
            """.data(using: .utf8)!
            return (200, json)
        }
        let repo = makeRepository()
        let contacts = try await repo.fetchContacts(userId: "u1", token: "tok")
        #expect(contacts.map(\.id) == ["c1"])
    }

    @Test func fetchContactsDoesNotIncludeOtherUsersFilterValue() async throws {
        URLProtocolStub.requestHandler = { request in
            let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
            let filter = components.queryItems?.first { $0.name == "filter" }?.value
            #expect(filter != "eigenaar = \"u2\"")
            let json = """
            {"items":[],"page":1,"perPage":200,"totalItems":0,"totalPages":1}
            """.data(using: .utf8)!
            return (200, json)
        }
        let repo = makeRepository()
        _ = try await repo.fetchContacts(userId: "u1", token: "tok")
    }

    // MARK: - createContact

    @Test func createContactPostsNaamTelefoonEnNotitie() async throws {
        URLProtocolStub.requestHandler = { request in
            #expect(request.httpMethod == "POST")
            let body = try! JSONSerialization.jsonObject(with: self.bodyData(from: request)) as! [String: Any]
            #expect(body["eigenaar"] as? String == "u1")
            #expect(body["naam"] as? String == "Sanae")
            #expect(body["telefoon"] as? String == "0698765432")
            #expect(body["notitie"] as? String == "")
            let json = """
            {"id":"c2","eigenaar":"u1","naam":"Sanae","telefoon":"0698765432","notitie":""}
            """.data(using: .utf8)!
            return (200, json)
        }
        let repo = makeRepository()
        let contact = try await repo.createContact(eigenaar: "u1", naam: "Sanae", telefoon: "0698765432", notitie: "", token: "tok")
        #expect(contact.naam == "Sanae")
    }

    // MARK: - updateContact

    @Test func updateContactSendsPatchWithNewFields() async throws {
        URLProtocolStub.requestHandler = { request in
            #expect(request.httpMethod == "PATCH")
            #expect(request.url!.absoluteString.contains("/api/collections/agenda_contacten/records/c1"))
            let body = try! JSONSerialization.jsonObject(with: self.bodyData(from: request)) as! [String: Any]
            #expect(body["naam"] as? String == "Karim B.")
            let json = """
            {"id":"c1","eigenaar":"u1","naam":"Karim B.","telefoon":"","notitie":""}
            """.data(using: .utf8)!
            return (200, json)
        }
        let repo = makeRepository()
        let contact = try await repo.updateContact(id: "c1", naam: "Karim B.", telefoon: "", notitie: "", token: "tok")
        #expect(contact.naam == "Karim B.")
    }

    // MARK: - deleteContact

    @Test func deleteContactSendsDeleteToRecordId() async throws {
        URLProtocolStub.requestHandler = { request in
            #expect(request.httpMethod == "DELETE")
            #expect(request.url!.absoluteString.contains("/api/collections/agenda_contacten/records/c1"))
            return (204, Data())
        }
        let repo = makeRepository()
        try await repo.deleteContact(id: "c1", token: "tok")
    }
}
