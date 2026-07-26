import Testing
import Foundation
@testable import Bovexa

@MainActor
struct VandaagViewModelTests {
    init() {
        URLProtocolStub.requestHandler = nil
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 9, _ min: Int = 0) -> Date {
        var comps = DateComponents()
        comps.year = y; comps.month = m; comps.day = d; comps.hour = h; comps.minute = min
        return Calendar(identifier: .gregorian).date(from: comps)!
    }

    /// UTC-vaste "nu"-momenten die corresponderen met de UTC-fixtures hieronder —
    /// voorkomt dat een toevallige exacte grens (host-tijdzone vs. "Z"-tijdstip) de test laat flakeren.
    private func utcNow(_ iso: String) -> Date {
        PBDate.parse(iso)!
    }

    @Test func loadPopulatesTodayEventsStatsAndOrgLogo() async {
        URLProtocolStub.requestHandler = { request in
            let path = request.url!.path
            if path.contains("agenda_events") {
                let json = """
                {"items":[
                  {"id":"a","owner":"me","title":"Ochtend","start":"2026-07-24 09:00:00.000Z","end":"2026-07-24 10:00:00.000Z","all_day":false},
                  {"id":"b","owner":"collega","title":"Middag","start":"2026-07-24 13:00:00.000Z","end":"2026-07-24 14:00:00.000Z","all_day":false},
                  {"id":"c","owner":"me","title":"Morgen","start":"2026-07-25 09:00:00.000Z","all_day":false}
                ],"page":1,"perPage":200,"totalItems":3,"totalPages":1}
                """.data(using: .utf8)!
                return (200, json)
            }
            let json = """
            {"items":[{"id":"m1","userId":"me","naam":"Ibrahim","email":"i@bovexa.nl","avatar":""},
                       {"id":"m2","userId":"collega","naam":"Chafia","email":"c@bovexa.nl","avatar":""}],
             "org":{"id":"org1","name":"Bovexa","logo":"banner.png"}}
            """.data(using: .utf8)!
            return (200, json)
        }

        let repository = EventRepository(client: PBClient(session: URLProtocolStub.makeSession()))
        let viewModel = VandaagViewModel(repository: repository, memberColors: MemberColors(), now: { self.utcNow("2026-07-24 11:30:00.000Z") })

        await viewModel.load(userId: "me", orgId: "org1", token: "tok")

        #expect(viewModel.todayEvents.map(\.id) == ["a", "b"])
        #expect(viewModel.appointmentCount == 2)
        #expect(viewModel.plannedHoursText == "2 uur")
        #expect(viewModel.nextEvent?.id == "b")
        #expect(viewModel.orgLogoURL?.absoluteString.contains("org1/banner.png") == true)
        #expect(viewModel.memberColors.firstName(for: "collega") == "Chafia")
        #expect(viewModel.hasLoadedOnce == true)
    }

    @Test func loadWithoutTodayEventsLeavesEmptyState() async {
        URLProtocolStub.requestHandler = { request in
            if request.url!.path.contains("agenda_events") {
                let json = """
                {"items":[],"page":1,"perPage":200,"totalItems":0,"totalPages":0}
                """.data(using: .utf8)!
                return (200, json)
            }
            let json = """
            {"data":{},"message":"Geen bedrijf gekoppeld.","status":400}
            """.data(using: .utf8)!
            return (400, json)
        }

        let repository = EventRepository(client: PBClient(session: URLProtocolStub.makeSession()))
        let viewModel = VandaagViewModel(repository: repository, memberColors: MemberColors(), now: { self.utcNow("2026-07-24 11:30:00.000Z") })

        await viewModel.load(userId: "me", orgId: nil, token: "tok")

        #expect(viewModel.todayEvents.isEmpty)
        #expect(viewModel.nextEvent == nil)
        #expect(viewModel.plannedHoursText == "0 uur")
        #expect(viewModel.orgLogoURL == nil)
    }

    @Test func loadWithOrgPrimesLabelStore() async {
        URLProtocolStub.requestHandler = { request in
            let path = request.url!.path
            if path.contains("agenda_labels") {
                let json = """
                {"items":[{"id":"l1","org":"org1","naam":"VSB","kleur":"#E08A3C","volgorde":0}],
                 "page":1,"perPage":200,"totalItems":1,"totalPages":1}
                """.data(using: .utf8)!
                return (200, json)
            }
            if path.contains("agenda_events") {
                let json = """
                {"items":[],"page":1,"perPage":200,"totalItems":0,"totalPages":0}
                """.data(using: .utf8)!
                return (200, json)
            }
            let json = """
            {"items":[],"org":null}
            """.data(using: .utf8)!
            return (200, json)
        }

        let repository = EventRepository(client: PBClient(session: URLProtocolStub.makeSession()))
        let labelRepository = LabelRepository(client: PBClient(session: URLProtocolStub.makeSession()))
        let viewModel = VandaagViewModel(repository: repository, labelRepository: labelRepository, now: { self.utcNow("2026-07-24 11:30:00.000Z") })

        await viewModel.load(userId: "me", orgId: "org1", token: "tok")

        #expect(viewModel.labelStore.label(for: "l1")?.naam == "VSB")
    }

    @Test func networkFailureLeavesEmptyStateInsteadOfCrashing() async {
        URLProtocolStub.requestHandler = nil // geen handler → netwerkfout
        let repository = EventRepository(client: PBClient(session: URLProtocolStub.makeSession()))
        let viewModel = VandaagViewModel(repository: repository, memberColors: MemberColors(), now: { self.utcNow("2026-07-24 11:30:00.000Z") })

        await viewModel.load(userId: "me", orgId: nil, token: "tok")

        #expect(viewModel.todayEvents.isEmpty)
        #expect(viewModel.hasLoadedOnce == true)
    }

    // MARK: - Externe agenda's (m9 plak 4, valkuil E)

    private func makeDefaults() -> UserDefaults {
        let suiteName = "bovexa-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @Test func externalEventsAppearInTodayEventsButNotInStats() async {
        URLProtocolStub.requestHandler = { request in
            if request.url!.path.contains("agenda_events") {
                let json = """
                {"items":[
                  {"id":"a","owner":"me","title":"Ochtend","start":"2026-07-24 09:00:00.000Z","end":"2026-07-24 10:00:00.000Z","all_day":false}
                ],"page":1,"perPage":200,"totalItems":1,"totalPages":1}
                """.data(using: .utf8)!
                return (200, json)
            }
            return (400, """
            {"data":{},"message":"Geen bedrijf gekoppeld.","status":400}
            """.data(using: .utf8)!)
        }
        let reader = FakeDeviceCalendarReader()
        reader.calendars = [DeviceCalendarInfo(id: "cal1", title: "Werk")]
        reader.eventsToReturn = [
            DeviceCalendarEvent(id: "ev1", calendarId: "cal1", calendarTitle: "Werk", title: "Overleg", startDate: utcNow("2026-07-24 13:00:00.000Z"), endDate: utcNow("2026-07-24 14:00:00.000Z"), isAllDay: false, location: nil, notes: nil)
        ]
        let defaults = makeDefaults()
        ExternalCalendarSelectionPreference.setSelectedIds(["cal1"], defaults: defaults)
        let repository = EventRepository(client: PBClient(session: URLProtocolStub.makeSession()))
        let viewModel = VandaagViewModel(
            repository: repository, memberColors: MemberColors(),
            externalCalendarService: ExternalCalendarService(reader: reader),
            now: { self.utcNow("2026-07-24 11:30:00.000Z") }, defaults: defaults
        )

        await viewModel.load(userId: "me", orgId: nil, token: "tok")

        #expect(viewModel.todayEvents.map(\.isExternal) == [false, true])
        // Besluit 26 juli: externe afspraken tellen mee in de cijfers — één eigen
        // afspraak plus één uit de gekoppelde agenda is samen twee.
        #expect(viewModel.appointmentCount == 2)
    }

    @Test func noExternalCalendarSelectedLeavesTodayEventsUnchanged() async {
        URLProtocolStub.requestHandler = { request in
            if request.url!.path.contains("agenda_events") {
                let json = """
                {"items":[{"id":"a","owner":"me","title":"Ochtend","start":"2026-07-24 09:00:00.000Z","all_day":false}],
                 "page":1,"perPage":200,"totalItems":1,"totalPages":1}
                """.data(using: .utf8)!
                return (200, json)
            }
            return (400, """
            {"data":{},"message":"Geen bedrijf gekoppeld.","status":400}
            """.data(using: .utf8)!)
        }
        let reader = FakeDeviceCalendarReader()
        reader.eventsToReturn = [
            DeviceCalendarEvent(id: "ev1", calendarId: "cal1", calendarTitle: "Werk", title: "Overleg", startDate: utcNow("2026-07-24 13:00:00.000Z"), endDate: utcNow("2026-07-24 14:00:00.000Z"), isAllDay: false, location: nil, notes: nil)
        ]
        let repository = EventRepository(client: PBClient(session: URLProtocolStub.makeSession()))
        let viewModel = VandaagViewModel(
            repository: repository, memberColors: MemberColors(),
            externalCalendarService: ExternalCalendarService(reader: reader),
            now: { self.utcNow("2026-07-24 11:30:00.000Z") }, defaults: makeDefaults()
        )

        await viewModel.load(userId: "me", orgId: nil, token: "tok")

        #expect(viewModel.todayEvents.map(\.id) == ["a"])
    }
}
