import Testing
import Foundation
@testable import Bovexa

struct LabelRepositoryTests {
    init() {
        URLProtocolStub.requestHandler = nil
    }

    private func makeRepository() -> LabelRepository {
        LabelRepository(client: PBClient(session: URLProtocolStub.makeSession()))
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

    // MARK: - fetchLabels

    @Test func fetchLabelsFiltersOnOrgAndSortsByVolgorde() async throws {
        URLProtocolStub.requestHandler = { request in
            let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
            #expect(components.queryItems?.first { $0.name == "filter" }?.value == "org = \"org1\"")
            #expect(components.queryItems?.first { $0.name == "sort" }?.value == "volgorde")
            let json = """
            {"items":[{"id":"l1","org":"org1","naam":"VSB","kleur":"#E08A3C","volgorde":0}],
             "page":1,"perPage":200,"totalItems":1,"totalPages":1}
            """.data(using: .utf8)!
            return (200, json)
        }
        let repo = makeRepository()
        let labels = try await repo.fetchLabels(orgId: "org1", token: "tok")
        #expect(labels.map(\.id) == ["l1"])
    }

    // MARK: - createLabel

    @Test func createLabelPostsNameColorAndOrder() async throws {
        URLProtocolStub.requestHandler = { request in
            #expect(request.httpMethod == "POST")
            let body = try! JSONSerialization.jsonObject(with: self.bodyData(from: request)) as! [String: Any]
            #expect(body["org"] as? String == "org1")
            #expect(body["naam"] as? String == "Kimberley")
            #expect(body["kleur"] as? String == "#D45AA4")
            #expect(body["volgorde"] as? Int == 3)
            let json = """
            {"id":"l2","org":"org1","naam":"Kimberley","kleur":"#D45AA4","volgorde":3}
            """.data(using: .utf8)!
            return (200, json)
        }
        let repo = makeRepository()
        let label = try await repo.createLabel(org: "org1", naam: "Kimberley", kleur: "#D45AA4", volgorde: 3, token: "tok")
        #expect(label.naam == "Kimberley")
    }

    // MARK: - renameLabel

    @Test func renameLabelSendsPatchWithNewNaam() async throws {
        URLProtocolStub.requestHandler = { request in
            #expect(request.httpMethod == "PATCH")
            #expect(request.url!.absoluteString.contains("/api/collections/agenda_labels/records/l1"))
            let body = try! JSONSerialization.jsonObject(with: self.bodyData(from: request)) as! [String: Any]
            #expect(body["naam"] as? String == "Nieuwe naam")
            let json = """
            {"id":"l1","org":"org1","naam":"Nieuwe naam","kleur":"#E08A3C","volgorde":0}
            """.data(using: .utf8)!
            return (200, json)
        }
        let repo = makeRepository()
        let label = try await repo.renameLabel(id: "l1", naam: "Nieuwe naam", token: "tok")
        #expect(label.naam == "Nieuwe naam")
    }

    // MARK: - updateColor

    @Test func updateColorSendsPatchWithNewKleur() async throws {
        URLProtocolStub.requestHandler = { request in
            #expect(request.httpMethod == "PATCH")
            let body = try! JSONSerialization.jsonObject(with: self.bodyData(from: request)) as! [String: Any]
            #expect(body["kleur"] as? String == "#3E87D6")
            let json = """
            {"id":"l1","org":"org1","naam":"VSB","kleur":"#3E87D6","volgorde":0}
            """.data(using: .utf8)!
            return (200, json)
        }
        let repo = makeRepository()
        let label = try await repo.updateColor(id: "l1", kleur: "#3E87D6", token: "tok")
        #expect(label.kleur == "#3E87D6")
    }

    // MARK: - deleteLabel

    @Test func deleteLabelSendsDeleteToRecordId() async throws {
        URLProtocolStub.requestHandler = { request in
            #expect(request.httpMethod == "DELETE")
            #expect(request.url!.absoluteString.contains("/api/collections/agenda_labels/records/l1"))
            return (204, Data())
        }
        let repo = makeRepository()
        try await repo.deleteLabel(id: "l1", token: "tok")
    }
}
