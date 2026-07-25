import Testing
import Foundation
@testable import Bovexa

struct NoticeRepositoryTests {
    init() {
        URLProtocolStub.requestHandler = nil
    }

    private func makeRepository() -> NoticeRepository {
        NoticeRepository(client: PBClient(session: URLProtocolStub.makeSession()))
    }

    @Test func fetchNoticesFiltersOnOrgAndSortsNewestFirst() async throws {
        URLProtocolStub.requestHandler = { request in
            let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
            #expect(components.queryItems?.first { $0.name == "filter" }?.value == "org = \"org1\"")
            #expect(components.queryItems?.first { $0.name == "sort" }?.value == "-created")
            let json = """
            {"items":[{"id":"n1","org":"org1","author":"u1","author_naam":"Ibrahim","body":"Hoi","created":"2026-07-24 09:00:00.000Z"}],
             "page":1,"perPage":200,"totalItems":1,"totalPages":1}
            """.data(using: .utf8)!
            return (200, json)
        }
        let repo = makeRepository()
        let notices = try await repo.fetchNotices(orgId: "org1", token: "tok")
        #expect(notices.map(\.id) == ["n1"])
    }

    @Test func createNoticePostsToRoute() async throws {
        URLProtocolStub.requestHandler = { request in
            #expect(request.url!.absoluteString.contains("/api/agenda/notices/create"))
            #expect(request.httpMethod == "POST")
            let json = """
            {"id":"n1","org":"org1","author":"u1","author_naam":"Ibrahim","title":"Titel","body":"Hoi","created":"2026-07-24 09:00:00.000Z"}
            """.data(using: .utf8)!
            return (200, json)
        }
        let repo = makeRepository()
        let notice = try await repo.createNotice(title: "Titel", body: "Hoi", token: "tok")
        #expect(notice.title == "Titel")
    }

    @Test func deleteNoticeSendsDeleteToRecordId() async throws {
        URLProtocolStub.requestHandler = { request in
            #expect(request.httpMethod == "DELETE")
            #expect(request.url!.absoluteString.contains("/api/collections/agenda_notices/records/n1"))
            return (204, Data())
        }
        let repo = makeRepository()
        try await repo.deleteNotice(id: "n1", token: "tok")
    }
}
