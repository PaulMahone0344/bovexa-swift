import Testing
import Foundation
@testable import Bovexa

/// .serialized: deze tests delen URLProtocolStub.requestHandler (een static var) en
/// zetten 'm elk op iets anders — parallelle uitvoering laat de ene test de mock van
/// de andere overschrijven.
@Suite(.serialized)
@MainActor
struct EventEditorViewModelTests {
    init() {
        URLProtocolStub.requestHandler = nil
    }

    /// UTC-vast: de mock-fixtures hieronder komen "over de lijn" binnen als UTC-string
    /// (via PBDate.parse) — zonder expliciete UTC-tijdzone hier zou host-tijdzone vs.
    /// "Z"-tijdstip de overlap-vergelijking laten flakeren (of stil mismatchen).
    private func date(_ h: Int, day: Int = 3) -> Date {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 8; comps.day = day; comps.hour = h
        comps.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: comps)!
    }

    private func makeEvent(
        id: String = "ev1", owner: String = "owner", title: String = "Origineel",
        start: Date? = nil, end: Date? = nil, assignee: [String] = []
    ) -> AgendaEvent {
        AgendaEvent(
            id: id, owner: owner, calendar: nil, category: .work, title: title,
            start: start ?? date(9), end: end ?? date(10), allDay: false, recurrence: nil,
            location: nil, notes: "notitie", klantNaam: "Jansen", assigneeStatus: [:],
            seriesId: nil, occurrenceDate: nil, assignee: assignee
        )
    }

    private func makeRepository() -> EventRepository {
        EventRepository(client: PBClient(session: URLProtocolStub.makeSession()))
    }

    private func makeViewModel(event: AgendaEvent, scheduler: FakeNotificationScheduler = FakeNotificationScheduler()) -> EventEditorViewModel {
        EventEditorViewModel(event: event, token: "tok", repository: makeRepository(), reminderService: ReminderService(scheduler: scheduler))
    }

    // MARK: - init populates from event

    @Test func initPopulatesFieldsFromEvent() {
        let event = makeEvent(start: date(9), end: date(10, day: 3))
        let vm = makeViewModel(event: event)
        #expect(vm.title == "Origineel")
        #expect(vm.category == .work)
        #expect(vm.start == date(9))
        #expect(vm.durationMin == 60)
        #expect(vm.notes == "notitie")
        #expect(vm.klantNaam == "Jansen")
    }

    @Test func initWithoutEndDefaultsToThirtyMinuteDuration() {
        let event = AgendaEvent(
            id: "ev1", owner: "owner", calendar: nil, category: nil, title: "T", start: date(9), end: nil,
            allDay: false, recurrence: nil, location: nil, notes: nil, klantNaam: nil,
            assigneeStatus: [:], seriesId: nil, occurrenceDate: nil
        )
        let vm = makeViewModel(event: event)
        #expect(vm.durationMin == 30)
    }

    // MARK: - save() validatie

    @Test func saveWithEmptyTitleSetsAlertAndDoesNotCallNetwork() async {
        URLProtocolStub.requestHandler = { _ in
            Issue.record("mocht geen netwerkverzoek doen")
            return (500, Data())
        }
        let vm = makeViewModel(event: makeEvent())
        vm.title = "   "
        let result = await vm.save()
        #expect(result == nil)
        #expect(vm.titleMissingAlert)
    }

    // MARK: - dubbele-boeking-check

    @Test func saveDetectsOverlapAndDoesNotUpdateYet() async {
        URLProtocolStub.requestHandler = { request in
            #expect(request.httpMethod != "PATCH")
            let json = """
            {"items":[{"id":"other","owner":"owner","title":"Ander","start":"2026-08-03 09:30:00.000Z","end":"2026-08-03 10:30:00.000Z","all_day":false}],
             "page":1,"perPage":200,"totalItems":1,"totalPages":1}
            """.data(using: .utf8)!
            return (200, json)
        }
        let vm = makeViewModel(event: makeEvent(start: date(9), end: date(10)))
        let result = await vm.save()
        #expect(result == nil)
        #expect(vm.overlapEvent?.id == "other")
    }

    @Test func saveExcludesOwnRecordFromOverlapCheck() async {
        URLProtocolStub.requestHandler = { request in
            if request.httpMethod == "PATCH" {
                let json = """
                {"id":"ev1","owner":"owner","title":"Origineel","start":"2026-08-03 09:00:00.000Z","end":"2026-08-03 10:00:00.000Z","all_day":false}
                """.data(using: .utf8)!
                return (200, json)
            }
            let json = """
            {"items":[{"id":"ev1","owner":"owner","title":"Origineel","start":"2026-08-03 09:00:00.000Z","end":"2026-08-03 10:00:00.000Z","all_day":false}],
             "page":1,"perPage":200,"totalItems":1,"totalPages":1}
            """.data(using: .utf8)!
            return (200, json)
        }
        let vm = makeViewModel(event: makeEvent(id: "ev1", start: date(9), end: date(10)))
        let result = await vm.save()
        #expect(result?.id == "ev1")
        #expect(vm.overlapEvent == nil)
    }

    @Test func saveConfirmedBypassesOverlapCheckAndSaves() async {
        URLProtocolStub.requestHandler = { request in
            #expect(request.httpMethod == "PATCH")
            let json = """
            {"id":"ev1","owner":"owner","title":"Origineel","start":"2026-08-03 09:00:00.000Z","end":"2026-08-03 10:00:00.000Z","all_day":false}
            """.data(using: .utf8)!
            return (200, json)
        }
        let vm = makeViewModel(event: makeEvent(id: "ev1"))
        let result = await vm.saveConfirmed()
        #expect(result?.id == "ev1")
    }

    // MARK: - opslaan + herinnering

    /// De starttijd moet ná `now` liggen: ReminderScheduling.fireDate plant bewust
    /// geen herinnering voor een moment dat al voorbij is. Met een vaste datum in
    /// de fixture ging deze test daarom vanzelf rood zodra die dag verstreken was.
    @Test func successfulSaveSchedulesReminderForReturnedEvent() async {
        let futureStart = Date().addingTimeInterval(3600)
        URLProtocolStub.requestHandler = { request in
            if request.httpMethod == "PATCH" {
                let json = """
                {"id":"ev1","owner":"owner","title":"Origineel","start":"\(PBDate.format(futureStart))","end":"\(PBDate.format(futureStart.addingTimeInterval(3600)))","all_day":false}
                """.data(using: .utf8)!
                return (200, json)
            }
            let json = """
            {"items":[],"page":1,"perPage":200,"totalItems":0,"totalPages":0}
            """.data(using: .utf8)!
            return (200, json)
        }
        let scheduler = FakeNotificationScheduler()
        let vm = makeViewModel(event: makeEvent(id: "ev1"), scheduler: scheduler)
        vm.reminderMin = 15
        _ = await vm.save()
        #expect(scheduler.scheduledIdentifiers == ["bovexaflow_reminder_ev1"])
    }

    @Test func saveFailureSetsAlertAndReturnsNil() async {
        URLProtocolStub.requestHandler = { request in
            if request.httpMethod == "PATCH" { return (500, Data("{}".utf8)) }
            let json = """
            {"items":[],"page":1,"perPage":200,"totalItems":0,"totalPages":0}
            """.data(using: .utf8)!
            return (200, json)
        }
        let vm = makeViewModel(event: makeEvent())
        let result = await vm.save()
        #expect(result == nil)
        #expect(vm.saveFailedAlert)
    }

    @Test func overlapCheckNetworkFailureSetsAlertInsteadOfSilentlySaving() async {
        URLProtocolStub.requestHandler = nil // geen handler → netwerkfout op de conflict-check
        let vm = makeViewModel(event: makeEvent())
        let result = await vm.save()
        #expect(result == nil)
        #expect(vm.saveFailedAlert)
    }

    // MARK: - Dubbele tik op Opslaan (M11 plak 4d)

    /// isSaving ging pas in performSave aan; tijdens de dubbele-boeking-check
    /// (netwerk) bleef "Opslaan" actief en startte een tweede tik een tweede ronde.
    @Test func aSecondSaveIsBlockedWhileTheFirstIsStillRunning() async {
        URLProtocolStub.requestHandler = { request in
            if request.httpMethod == "PATCH" {
                return (200, Data("""
                {"id":"ev1","owner":"owner","title":"Origineel","start":"2026-08-03 09:00:00.000Z","all_day":false}
                """.utf8))
            }
            return (200, Data("""
            {"items":[],"page":1,"perPage":200,"totalItems":0,"totalPages":0}
            """.utf8))
        }
        let vm = makeViewModel(event: makeEvent(id: "ev1"))

        async let first = vm.save()
        async let second = vm.save()
        let results = await [first, second]

        // Precies één van de twee mag doorgaan.
        #expect(results.compactMap { $0 }.count == 1)
        #expect(!vm.isSaving)
    }

}
