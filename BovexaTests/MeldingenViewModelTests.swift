import Testing
import Foundation
@testable import Bovexa

@MainActor
struct MeldingenViewModelTests {
    init() {
        URLProtocolStub.requestHandler = nil
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "bovexa-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func makeViewModel(userId: String = "me", orgId: String? = "org1", seenStore: NoticesSeenStore? = nil) -> MeldingenViewModel {
        let session = URLProtocolStub.makeSession()
        return MeldingenViewModel(
            userId: userId, orgId: orgId, token: "tok",
            eventRepository: EventRepository(client: PBClient(session: session)),
            noticeRepository: NoticeRepository(client: PBClient(session: session)),
            companyRepository: CompanyRepository(client: PBClient(session: session)),
            seenStore: seenStore ?? NoticesSeenStore(defaults: makeDefaults())
        )
    }

    /// Handler die routeert op basis van het pad — events/notices/members hebben elk
    /// hun eigen response nodig binnen dezelfde `load()`.
    private func routedHandler(
        events: String = """
        {"items":[],"page":1,"perPage":200,"totalItems":0,"totalPages":0}
        """,
        notices: String = """
        {"items":[],"page":1,"perPage":200,"totalItems":0,"totalPages":0}
        """,
        role: String = "member"
    ) -> (URLRequest) -> (Int, Data) {
        { request in
            let path = request.url!.path
            if path.contains("agenda_events") {
                return (200, events.data(using: .utf8)!)
            }
            if path.contains("agenda_notices") {
                return (200, notices.data(using: .utf8)!)
            }
            if path.contains("company/members") {
                let json = """
                {"items":[{"id":"m1","userId":"me","naam":"Ik","email":"ik@bovexa.nl","avatar":"","role":"\(role)","status":"active","isOwner":false,"magMaken":true,"magWijzigen":true,"magVerwijderen":true,"magKlantZien":true,"magAgendaAnderenZien":true}],
                 "seats_max":3,"plan":"free","join_code":"ABC123","org":null}
                """
                return (200, json.data(using: .utf8)!)
            }
            return (404, Data())
        }
    }

    // MARK: - canPost (valkuil D/E)

    @Test func canPostIsFalseForMember() async {
        URLProtocolStub.requestHandler = routedHandler(role: "member")
        let vm = makeViewModel()
        await vm.load()
        #expect(!vm.canPost)
    }

    @Test func canPostIsTrueForAdmin() async {
        URLProtocolStub.requestHandler = routedHandler(role: "admin")
        let vm = makeViewModel()
        await vm.load()
        #expect(vm.canPost)
    }

    // MARK: - openen markeert gezien (valkuil E)

    @Test func loadMarksNoticesAsSeen() async {
        let defaults = makeDefaults()
        let seenStore = NoticesSeenStore(defaults: defaults)
        URLProtocolStub.requestHandler = routedHandler()
        let vm = makeViewModel(seenStore: seenStore)
        #expect(seenStore.lastSeen(userId: "me") == nil)
        await vm.load()
        #expect(seenStore.lastSeen(userId: "me") != nil)
    }

    @Test func loadWithoutOrgSkipsNoticesAndDoesNotMarkSeen() async {
        let defaults = makeDefaults()
        let seenStore = NoticesSeenStore(defaults: defaults)
        URLProtocolStub.requestHandler = routedHandler()
        let vm = makeViewModel(orgId: nil, seenStore: seenStore)
        await vm.load()
        #expect(vm.notices.isEmpty)
        #expect(seenStore.lastSeen(userId: "me") == nil)
    }

    // MARK: - respond (valkuil B, hergebruik EventRepository/AssignmentHelpers)

    @Test func respondRemovesFromPendingOptimisticallyOnSuccess() async {
        let events = """
        {"items":[{"id":"a","owner":"collega","title":"Klus","start":"2026-07-24 09:00:00.000Z","all_day":false,"assignee":["me"],"assignee_status":{}}],
         "page":1,"perPage":200,"totalItems":1,"totalPages":1}
        """
        URLProtocolStub.requestHandler = routedHandler(events: events)
        let vm = makeViewModel()
        await vm.load()
        #expect(vm.pending.count == 1)

        URLProtocolStub.requestHandler = { request in
            (200, """
            {"id":"a","owner":"collega","title":"Klus","start":"2026-07-24 09:00:00.000Z","all_day":false}
            """.data(using: .utf8)!)
        }
        await vm.respond(vm.pending[0], status: "accepted")
        #expect(vm.pending.isEmpty)
        #expect(!vm.respondFailedAlert)
    }

    @Test func respondRollsBackOnFailure() async {
        let events = """
        {"items":[{"id":"a","owner":"collega","title":"Klus","start":"2026-07-24 09:00:00.000Z","all_day":false,"assignee":["me"],"assignee_status":{}}],
         "page":1,"perPage":200,"totalItems":1,"totalPages":1}
        """
        URLProtocolStub.requestHandler = routedHandler(events: events)
        let vm = makeViewModel()
        await vm.load()

        URLProtocolStub.requestHandler = { _ in (400, """
        {"message":"Mislukt"}
        """.data(using: .utf8)!) }
        await vm.respond(vm.pending[0], status: "accepted")
        #expect(vm.pending.count == 1)
        #expect(vm.respondFailedAlert)
    }

    // MARK: - canDelete (alleen eigen mededeling)

    @Test func canDeleteOnlyOwnNotice() {
        let vm = makeViewModel()
        let mine = Notice(id: "n1", org: "org1", author: "me", authorNaam: "Ik", title: nil, body: "Hoi", created: Date())
        let other = Notice(id: "n2", org: "org1", author: "collega", authorNaam: "Collega", title: nil, body: "Hoi", created: Date())
        #expect(vm.canDelete(mine))
        #expect(!vm.canDelete(other))
    }

    // MARK: - submit (nieuwe mededeling)

    @Test func submitInsertsNewNoticeAtFrontAndClearsCompose() async {
        URLProtocolStub.requestHandler = { request in
            (200, """
            {"id":"n1","org":"org1","author":"me","author_naam":"Ik","title":"Titel","body":"Bericht","created":"2026-07-24 09:00:00.000Z"}
            """.data(using: .utf8)!)
        }
        let vm = makeViewModel()
        vm.composeTitle = "Titel"
        vm.composeBody = "Bericht"
        await vm.submit()
        #expect(vm.notices.map(\.id) == ["n1"])
        #expect(vm.composeBody.isEmpty)
        #expect(!vm.composeOpen)
    }

    @Test func submitDoesNothingWithEmptyBody() async {
        let vm = makeViewModel()
        vm.composeBody = "   "
        await vm.submit()
        #expect(vm.notices.isEmpty)
    }
}
