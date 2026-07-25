import Testing
import Foundation
@testable import Bovexa

@MainActor
struct ProfielViewModelTests {
    init() {
        URLProtocolStub.requestHandler = nil
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 9) -> Date {
        var comps = DateComponents()
        comps.year = y; comps.month = m; comps.day = d; comps.hour = h
        return Calendar(identifier: .gregorian).date(from: comps)!
    }

    private func utcNow(_ iso: String) -> Date {
        PBDate.parse(iso)!
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "bovexa-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    // MARK: - Begroeting

    @Test func greetingSubtitleBeforeLoadIsNeutral() {
        let vm = ProfielViewModel(repository: EventRepository(client: PBClient(session: URLProtocolStub.makeSession())), defaults: makeDefaults())
        #expect(vm.greetingSubtitle == "Fijn dat je er weer bent.")
    }

    @Test func greetingSubtitleZeroToday() async {
        URLProtocolStub.requestHandler = { _ in (200, """
        {"items":[],"page":1,"perPage":200,"totalItems":0,"totalPages":0}
        """.data(using: .utf8)!) }
        let vm = ProfielViewModel(
            repository: EventRepository(client: PBClient(session: URLProtocolStub.makeSession())),
            now: { self.utcNow("2026-07-24 11:30:00.000Z") },
            defaults: makeDefaults()
        )
        await vm.load(userId: "me", orgId: nil, token: "tok")
        #expect(vm.greetingSubtitle == "Geen afspraken vandaag — rustige dag.")
    }

    @Test func greetingSubtitleSingularAndPlural() async {
        URLProtocolStub.requestHandler = { _ in (200, """
        {"items":[
          {"id":"a","owner":"me","title":"Ochtend","start":"2026-07-24 09:00:00.000Z","all_day":false}
        ],"page":1,"perPage":200,"totalItems":1,"totalPages":1}
        """.data(using: .utf8)!) }
        let vm = ProfielViewModel(
            repository: EventRepository(client: PBClient(session: URLProtocolStub.makeSession())),
            now: { self.utcNow("2026-07-24 11:30:00.000Z") },
            defaults: makeDefaults()
        )
        await vm.load(userId: "me", orgId: nil, token: "tok")
        #expect(vm.greetingSubtitle == "Je hebt vandaag 1 afspraak.")
    }

    // MARK: - Teller en stip (valkuil D/E-voorbereiding)

    @Test func pendingCountAndDotReflectWaitingAssignments() async {
        URLProtocolStub.requestHandler = { _ in (200, """
        {"items":[
          {"id":"a","owner":"collega","title":"Klus","start":"2026-07-24 09:00:00.000Z","all_day":false,"assignee":["me"],"assignee_status":{}}
        ],"page":1,"perPage":200,"totalItems":1,"totalPages":1}
        """.data(using: .utf8)!) }
        let vm = ProfielViewModel(
            repository: EventRepository(client: PBClient(session: URLProtocolStub.makeSession())),
            now: { self.utcNow("2026-07-24 11:30:00.000Z") },
            defaults: makeDefaults()
        )
        await vm.load(userId: "me", orgId: nil, token: "tok")
        #expect(vm.pendingCount == 1)
        #expect(vm.showUnreadDot)
    }

    @Test func noDotWithoutPendingAssignments() async {
        URLProtocolStub.requestHandler = { _ in (200, """
        {"items":[],"page":1,"perPage":200,"totalItems":0,"totalPages":0}
        """.data(using: .utf8)!) }
        let vm = ProfielViewModel(repository: EventRepository(client: PBClient(session: URLProtocolStub.makeSession())), defaults: makeDefaults())
        await vm.load(userId: "me", orgId: nil, token: "tok")
        #expect(vm.pendingCount == 0)
        #expect(!vm.showUnreadDot)
    }

    @Test func networkFailureLeavesNeutralStateInsteadOfCrashing() async {
        URLProtocolStub.requestHandler = nil
        let vm = ProfielViewModel(repository: EventRepository(client: PBClient(session: URLProtocolStub.makeSession())), defaults: makeDefaults())
        await vm.load(userId: "me", orgId: nil, token: "tok")
        #expect(vm.pendingCount == 0)
        #expect(!vm.showUnreadDot)
    }

    // MARK: - Ongelezen mededeling (valkuil E, m6 plak 5)

    private func routedHandler(events: String, notices: String) -> (URLRequest) -> (Int, Data) {
        { request in
            let path = request.url!.path
            if path.contains("agenda_notices") { return (200, notices.data(using: .utf8)!) }
            return (200, events.data(using: .utf8)!)
        }
    }

    private let emptyEvents = """
    {"items":[],"page":1,"perPage":200,"totalItems":0,"totalPages":0}
    """

    @Test func dotIsOnWhenNoticeNeverSeenWithOrg() async {
        let notices = """
        {"items":[{"id":"n1","org":"org1","author":"collega","author_naam":"Collega","body":"Hoi","created":"2026-07-24 09:00:00.000Z"}],
         "page":1,"perPage":200,"totalItems":1,"totalPages":1}
        """
        URLProtocolStub.requestHandler = routedHandler(events: emptyEvents, notices: notices)
        let vm = ProfielViewModel(
            repository: EventRepository(client: PBClient(session: URLProtocolStub.makeSession())),
            noticeRepository: NoticeRepository(client: PBClient(session: URLProtocolStub.makeSession())),
            defaults: makeDefaults()
        )
        await vm.load(userId: "me", orgId: "org1", token: "tok")
        #expect(vm.showUnreadDot)
    }

    @Test func dotIsOffWhenNoticeAlreadySeen() async {
        let notices = """
        {"items":[{"id":"n1","org":"org1","author":"collega","author_naam":"Collega","body":"Hoi","created":"2026-07-24 09:00:00.000Z"}],
         "page":1,"perPage":200,"totalItems":1,"totalPages":1}
        """
        URLProtocolStub.requestHandler = routedHandler(events: emptyEvents, notices: notices)
        let defaults = makeDefaults()
        let seenStore = NoticesSeenStore(defaults: defaults)
        seenStore.markSeen(userId: "me", at: utcNow("2026-07-25 09:00:00.000Z"))
        let vm = ProfielViewModel(
            repository: EventRepository(client: PBClient(session: URLProtocolStub.makeSession())),
            noticeRepository: NoticeRepository(client: PBClient(session: URLProtocolStub.makeSession())),
            seenStore: seenStore,
            defaults: defaults
        )
        await vm.load(userId: "me", orgId: "org1", token: "tok")
        #expect(!vm.showUnreadDot)
    }

    @Test func dotStaysOnFromPendingEvenWithoutOrg() async {
        URLProtocolStub.requestHandler = { _ in (200, """
        {"items":[
          {"id":"a","owner":"collega","title":"Klus","start":"2026-07-24 09:00:00.000Z","all_day":false,"assignee":["me"],"assignee_status":{}}
        ],"page":1,"perPage":200,"totalItems":1,"totalPages":1}
        """.data(using: .utf8)!) }
        let vm = ProfielViewModel(repository: EventRepository(client: PBClient(session: URLProtocolStub.makeSession())), defaults: makeDefaults())
        await vm.load(userId: "me", orgId: nil, token: "tok")
        #expect(vm.showUnreadDot)
    }

    // MARK: - iPhone Agenda-sync (valkuil H, lokale opslag)

    @Test func deviceSyncDefaultsToOn() {
        let vm = ProfielViewModel(defaults: makeDefaults())
        #expect(vm.deviceSyncEnabled)
    }

    @Test func settingDeviceSyncPersistsToDefaults() {
        let defaults = makeDefaults()
        let vm = ProfielViewModel(defaults: defaults)
        vm.setDeviceSync(false)
        #expect(!vm.deviceSyncEnabled)
        #expect(!DeviceCalendarSyncPreference.isEnabled(defaults: defaults))

        let vmReloaded = ProfielViewModel(defaults: defaults)
        #expect(!vmReloaded.deviceSyncEnabled)
    }
}
