import Testing
import Foundation
@testable import Bovexa

@MainActor
struct AgendaViewModelTests {
    init() {
        URLProtocolStub.requestHandler = nil
    }

    private func makeViewModel() -> AgendaViewModel {
        let repository = EventRepository(client: PBClient(session: URLProtocolStub.makeSession()))
        let labelRepository = LabelRepository(client: PBClient(session: URLProtocolStub.makeSession()))
        return AgendaViewModel(repository: repository, labelRepository: labelRepository)
    }

    private func stubEmptyEventsAndMembers(labelsJSON: String) {
        URLProtocolStub.requestHandler = { request in
            let path = request.url!.path
            if path.contains("agenda_labels") {
                return (200, labelsJSON.data(using: .utf8)!)
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
    }

    @Test func loadWithOrgPrimesLabelStore() async {
        stubEmptyEventsAndMembers(labelsJSON: """
        {"items":[{"id":"l1","org":"org1","naam":"VSB","kleur":"#E08A3C","volgorde":0}],
         "page":1,"perPage":200,"totalItems":1,"totalPages":1}
        """)
        let viewModel = makeViewModel()

        await viewModel.load(userId: "me", orgId: "org1", token: "tok")

        #expect(viewModel.labelStore.label(for: "l1")?.naam == "VSB")
    }

    @Test func loadWithoutOrgLeavesLabelStoreEmpty() async {
        stubEmptyEventsAndMembers(labelsJSON: """
        {"items":[],"page":1,"perPage":200,"totalItems":0,"totalPages":0}
        """)
        let viewModel = makeViewModel()

        await viewModel.load(userId: "me", orgId: nil, token: "tok")

        #expect(viewModel.labelStore.orderedLabels.isEmpty)
    }

    // MARK: - Externe agenda's (m9 plak 4, valkuil D/E/G)

    private func makeDefaults() -> UserDefaults {
        let suiteName = "bovexa-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @Test func noExternalCalendarSelectedLeavesEventsUnchanged() async {
        stubEmptyEventsAndMembers(labelsJSON: """
        {"items":[],"page":1,"perPage":200,"totalItems":0,"totalPages":0}
        """)
        let reader = FakeDeviceCalendarReader()
        reader.calendars = [DeviceCalendarInfo(id: "cal1", title: "Werk")]
        reader.eventsToReturn = [
            DeviceCalendarEvent(id: "ev1", calendarId: "cal1", calendarTitle: "Werk", title: "Overleg", startDate: Date(), endDate: Date(), isAllDay: false, location: nil, notes: nil)
        ]
        let viewModel = AgendaViewModel(
            repository: EventRepository(client: PBClient(session: URLProtocolStub.makeSession())),
            labelRepository: LabelRepository(client: PBClient(session: URLProtocolStub.makeSession())),
            externalCalendarService: ExternalCalendarService(reader: reader),
            defaults: makeDefaults()
        )
        await viewModel.load(userId: "me", orgId: "org1", token: "tok")
        #expect(viewModel.events.isEmpty)
    }

    @Test func selectedExternalCalendarAddsEventsWithoutTouchingOwnEvents() async {
        URLProtocolStub.requestHandler = { request in
            let path = request.url!.path
            if path.contains("agenda_labels") {
                return (200, """
                {"items":[],"page":1,"perPage":200,"totalItems":0,"totalPages":0}
                """.data(using: .utf8)!)
            }
            if path.contains("agenda_events") {
                return (200, """
                {"items":[{"id":"a","owner":"me","title":"Eigen","start":"2026-07-24 09:00:00.000Z","all_day":false}],
                 "page":1,"perPage":200,"totalItems":1,"totalPages":1}
                """.data(using: .utf8)!)
            }
            return (200, """
            {"items":[],"org":null}
            """.data(using: .utf8)!)
        }
        let reader = FakeDeviceCalendarReader()
        reader.calendars = [DeviceCalendarInfo(id: "cal1", title: "Werk")]
        reader.eventsToReturn = [
            DeviceCalendarEvent(id: "ev1", calendarId: "cal1", calendarTitle: "Werk", title: "Overleg", startDate: Date(), endDate: Date(), isAllDay: false, location: nil, notes: nil)
        ]
        let defaults = makeDefaults()
        ExternalCalendarSelectionPreference.setSelectedIds(["cal1"], defaults: defaults)
        let viewModel = AgendaViewModel(
            repository: EventRepository(client: PBClient(session: URLProtocolStub.makeSession())),
            labelRepository: LabelRepository(client: PBClient(session: URLProtocolStub.makeSession())),
            externalCalendarService: ExternalCalendarService(reader: reader),
            defaults: defaults
        )
        await viewModel.load(userId: "me", orgId: "org1", token: "tok")
        #expect(viewModel.events.count == 2)
        #expect(viewModel.events.contains { $0.id == "a" && $0.isExternal == false })
        #expect(viewModel.events.contains { $0.isExternal == true })
    }

    /// Het venster van de externe agenda loopt één maand vóór en ná de getoonde
    /// maand. Bladert de gebruiker verder, dan moet dat venster meelopen — anders
    /// verdwijnen de externe afspraken zonder uitleg terwijl de eigen blijven staan.
    @Test func browsingToAnotherMonthRefetchesExternalEventsAndKeepsOwn() async {
        URLProtocolStub.requestHandler = { request in
            let path = request.url!.path
            if path.contains("agenda_labels") {
                return (200, """
                {"items":[],"page":1,"perPage":200,"totalItems":0,"totalPages":0}
                """.data(using: .utf8)!)
            }
            if path.contains("agenda_events") {
                return (200, """
                {"items":[{"id":"a","owner":"me","title":"Eigen","start":"2026-07-24 09:00:00.000Z","all_day":false}],
                 "page":1,"perPage":200,"totalItems":1,"totalPages":1}
                """.data(using: .utf8)!)
            }
            return (200, """
            {"items":[],"org":null}
            """.data(using: .utf8)!)
        }
        let reader = FakeDeviceCalendarReader()
        reader.calendars = [DeviceCalendarInfo(id: "cal1", title: "Werk")]
        reader.eventsToReturn = [
            DeviceCalendarEvent(id: "ev1", calendarId: "cal1", calendarTitle: "Werk", title: "Overleg", startDate: Date(), endDate: Date(), isAllDay: false, location: nil, notes: nil)
        ]
        let defaults = makeDefaults()
        ExternalCalendarSelectionPreference.setSelectedIds(["cal1"], defaults: defaults)
        let viewModel = AgendaViewModel(
            repository: EventRepository(client: PBClient(session: URLProtocolStub.makeSession())),
            labelRepository: LabelRepository(client: PBClient(session: URLProtocolStub.makeSession())),
            externalCalendarService: ExternalCalendarService(reader: reader),
            defaults: defaults
        )
        await viewModel.load(userId: "me", orgId: "org1", token: "tok")

        reader.eventsToReturn = [
            DeviceCalendarEvent(id: "ev2", calendarId: "cal1", calendarTitle: "Werk", title: "Volgende maand", startDate: Date(), endDate: Date(), isAllDay: false, location: nil, notes: nil)
        ]
        viewModel.goToNextMonth()
        await viewModel.refreshExternalForDisplayedMonth()

        #expect(viewModel.events.contains { $0.id == "a" && $0.isExternal == false })
        #expect(viewModel.events.contains { $0.title == "Volgende maand" })
        #expect(!viewModel.events.contains { $0.title == "Overleg" })
    }

    // MARK: - Wie zie je in de agenda (26 juli: eigen agenda is het startpunt)

    /// Stub met twee collega's naast de ingelogde gebruiker, allemaal met het recht
    /// om andermans agenda te zien.
    private func stubMembers() {
        URLProtocolStub.requestHandler = { request in
            let path = request.url!.path
            if path.contains("agenda_labels") {
                return (200, """
                {"items":[],"page":1,"perPage":200,"totalItems":0,"totalPages":0}
                """.data(using: .utf8)!)
            }
            if path.contains("agenda_events") {
                return (200, """
                {"items":[{"id":"mine","owner":"me","title":"Eigen","start":"2026-07-24 09:00:00.000Z","all_day":false},
                          {"id":"his","owner":"u2","title":"Van Daan","start":"2026-07-24 10:00:00.000Z","all_day":false}],
                 "page":1,"perPage":200,"totalItems":2,"totalPages":2}
                """.data(using: .utf8)!)
            }
            return (200, """
            {"items":[
              {"id":"m1","userId":"me","naam":"Ik","email":"ik@bovexa.nl","avatar":"","role":"admin","status":"active","is_owner":true,
               "mag_maken":true,"mag_wijzigen":true,"mag_verwijderen":true,"mag_klant_zien":true,"mag_agenda_anderen_zien":true},
              {"id":"m2","userId":"u2","naam":"Daan","email":"daan@bovexa.nl","avatar":"","role":"member","status":"active","is_owner":false,
               "mag_maken":true,"mag_wijzigen":true,"mag_verwijderen":false,"mag_klant_zien":true,"mag_agenda_anderen_zien":false},
              {"id":"m3","userId":"u3","naam":"Nora","email":"nora@bovexa.nl","avatar":"","role":"member","status":"active","is_owner":false,
               "mag_maken":true,"mag_wijzigen":true,"mag_verwijderen":false,"mag_klant_zien":true,"mag_agenda_anderen_zien":false}
            ],"org":null}
            """.data(using: .utf8)!)
        }
    }

    @Test func agendaStartsOnYourOwnEventsOnly() async {
        stubMembers()
        let viewModel = makeViewModel()

        await viewModel.load(userId: "me", orgId: "org1", token: "tok")

        #expect(viewModel.selectedPeople == ["me"])
        #expect(viewModel.extraPeople.isEmpty)
        #expect(Set(viewModel.visibleEvents.map(\.id)) == ["mine"])
    }

    @Test func togglingAColleagueAddsAndRemovesTheirEvents() async {
        stubMembers()
        let viewModel = makeViewModel()
        await viewModel.load(userId: "me", orgId: "org1", token: "tok")

        viewModel.togglePerson("u2")
        #expect(viewModel.extraPeople == ["u2"])
        #expect(Set(viewModel.visibleEvents.map(\.id)) == ["mine", "his"])

        viewModel.togglePerson("u2")
        #expect(viewModel.extraPeople.isEmpty)
        #expect(Set(viewModel.visibleEvents.map(\.id)) == ["mine"])
    }

    /// Jezelf uitvinken kan niet; anders kun je alles uitzetten en naar een leeg
    /// raster kijken zonder te weten waarom.
    @Test func youCannotSwitchOffYourOwnAgenda() async {
        stubMembers()
        let viewModel = makeViewModel()
        await viewModel.load(userId: "me", orgId: "org1", token: "tok")

        viewModel.togglePerson("me")

        #expect(viewModel.selectedPeople.contains("me"))
    }

    @Test func everyoneSelectsAllMembersAndOnlyMeReturns() async {
        stubMembers()
        let viewModel = makeViewModel()
        await viewModel.load(userId: "me", orgId: "org1", token: "tok")

        viewModel.showEveryone()
        #expect(viewModel.selectedPeople == ["me", "u2", "u3"])

        viewModel.showOnlyOwnAgenda()
        #expect(viewModel.selectedPeople == ["me"])
    }
}
