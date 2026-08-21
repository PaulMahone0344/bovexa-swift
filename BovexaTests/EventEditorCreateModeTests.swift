import Testing
import Foundation
@testable import Bovexa

/// EventEditorViewModel in create-modus (M12 plak 2): defaults uit de voorzet,
/// dubbele-boeking-check zonder uitzondering, createEvent met source 'manual' en
/// een herinnering op het id dat de server teruggeeft.
///
/// .serialized: deelt URLProtocolStub.requestHandler (static var) met de andere
/// netwerk-tests.
@Suite(.serialized)
@MainActor
struct EventEditorCreateModeTests {
    init() {
        URLProtocolStub.requestHandler = nil
        URLProtocolStub.errorHandler = nil
    }

    private let calendar = Calendar(identifier: .gregorian)

    private func day(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        var comps = DateComponents()
        comps.year = year; comps.month = month; comps.day = day
        comps.hour = hour; comps.minute = minute
        return calendar.date(from: comps)!
    }

    private func makeViewModel(
        seed: NieuweAfspraakSeed = .empty, org: String = "org1", defaultDurationMin: Int = EventEditorViewModel.fallbackDurationMin,
        now: Date = Date(), scheduler: FakeNotificationScheduler = FakeNotificationScheduler(),
        calendarWriter: FakeDeviceCalendarWriter = FakeDeviceCalendarWriter(),
        calendarDefaults: UserDefaults? = nil
    ) -> EventEditorViewModel {
        EventEditorViewModel(
            mode: .create(seed), ownerId: "u1", org: org, token: "tok",
            defaultDurationMin: defaultDurationMin, now: now,
            repository: EventRepository(client: PBClient(session: URLProtocolStub.makeSession())),
            reminderService: ReminderService(scheduler: scheduler),
            deviceCalendarService: DeviceCalendarService(
                writer: calendarWriter,
                preferenceDefaults: calendarDefaults ?? UserDefaults(suiteName: "EventEditorCreateModeTests.\(UUID().uuidString)")!
            )
        )
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

    private static let createdRecord = """
    {"id":"new1","owner":"u1","title":"Kapper","start":"2026-08-03 09:00:00.000Z","end":"2026-08-03 10:00:00.000Z","all_day":false}
    """

    private static let emptyList = """
    {"items":[],"page":1,"perPage":200,"totalItems":0,"totalPages":0}
    """

    /// GET = de dubbele-boeking-check, POST = het aanmaken. `capture` krijgt de
    /// POST-body als woordenboek.
    private func stubCreate(capture: @escaping ([String: Any]) -> Void = { _ in }) {
        URLProtocolStub.requestHandler = { request in
            if request.httpMethod == "GET" { return (200, Data(Self.emptyList.utf8)) }
            capture((try? JSONSerialization.jsonObject(with: self.bodyData(from: request))) as? [String: Any] ?? [:])
            return (200, Data(Self.createdRecord.utf8))
        }
    }

    // MARK: - defaults uit de voorzet

    @Test func defaultsComeFromTheSeed() {
        let vm = makeViewModel(seed: .forHour(14, on: day(2026, 8, 3)))
        #expect(vm.isCreating)
        #expect(vm.originalEvent == nil)
        #expect(vm.title.isEmpty)
        #expect(vm.category == .work)
        #expect(vm.start == day(2026, 8, 3, hour: 14))
        #expect(vm.durationMin == 60)
        #expect(vm.visibility == "private")
        #expect(vm.reminderMin == 0)
        #expect(vm.assignee.isEmpty)
        #expect(vm.label == nil)
        #expect(vm.contactId == nil)
        #expect(vm.notes.isEmpty)
    }

    @Test func companyDefaultDurationIsUsedWhenGiven() {
        let vm = makeViewModel(seed: .forDay(day(2026, 8, 3)), defaultDurationMin: 45)
        #expect(vm.durationMin == 45)
        #expect(vm.start == day(2026, 8, 3, hour: 9))
    }

    @Test func withoutADayTheFormOpensAtTheNextWholeHour() {
        let vm = makeViewModel(seed: .empty, now: day(2026, 8, 3, hour: 14, minute: 20))
        #expect(vm.start == day(2026, 8, 3, hour: 15))
    }

    // MARK: - opslaan

    @Test func emptyTitleDoesNotCallTheNetwork() async {
        URLProtocolStub.requestHandler = { _ in
            Issue.record("mocht geen netwerkverzoek doen")
            return (500, Data())
        }
        let vm = makeViewModel()
        let result = await vm.save()
        #expect(result == nil)
        #expect(vm.titleMissingAlert)
    }

    @Test func createWritesSourceManualWithEmptyRawInput() async {
        var body: [String: Any] = [:]
        stubCreate { body = $0 }
        let vm = makeViewModel(seed: .forHour(9, on: day(2026, 8, 3)))
        vm.title = "  Kapper  "

        let created = await vm.save()

        #expect(created?.id == "new1")
        #expect(body["source"] as? String == "manual")
        #expect(body["raw_input"] as? String == "")
        #expect(body["owner"] as? String == "u1")
        #expect(body["org"] as? String == "org1")
        #expect(body["title"] as? String == "Kapper")
        #expect(body["visibility"] as? String == "private")
        #expect(body["reminder_min"] as? Int == 0)
    }

    @Test func chosenVisibilityAssigneeAndLabelEndUpInTheCreateBody() async {
        var body: [String: Any] = [:]
        stubCreate { body = $0 }
        let vm = makeViewModel(seed: .forDay(day(2026, 8, 3)))
        vm.title = "Ketel"
        vm.visibility = "company"
        vm.assignee = ["u2"]
        vm.label = "l1"

        _ = await vm.save()

        #expect(body["visibility"] as? String == "company")
        #expect(body["assignee"] as? [String] == ["u2"])
        // Toegewezenen horen altijd óók in viewers (valkuil D van de planner).
        #expect(body["viewers"] as? [String] == ["u2"])
        #expect(body["assignee_status"] as? [String: String] == ["u2": "pending"])
        #expect(body["label"] as? String == "l1")
    }

    /// Zonder bedrijf: zichtbaarheid altijd privé, toewijzingen en label vervallen —
    /// zelfde regel als de planner (valkuil C daar).
    @Test func withoutOrgVisibilityStaysPrivateAndAssigneesAreDropped() async {
        var body: [String: Any] = [:]
        stubCreate { body = $0 }
        let vm = makeViewModel(seed: .forDay(day(2026, 8, 3)), org: "")
        vm.title = "Kapper"
        vm.visibility = "company"
        vm.assignee = ["u2"]
        vm.label = "l1"

        _ = await vm.save()

        #expect(body["org"] as? String == "")
        #expect(body["visibility"] as? String == "private")
        #expect(body["assignee"] as? [String] == [])
        #expect(body["label"] == nil)
    }

    /// Het formulier heeft een notitieveld; zonder dit veld in de create-payload
    /// verdween een ingetypte notitie stilletjes bij het toevoegen.
    @Test func aTypedNoteEndsUpInTheCreateBody() async {
        var body: [String: Any] = [:]
        stubCreate { body = $0 }
        let vm = makeViewModel()
        vm.title = "Kapper"
        vm.notes = "  Sleutel bij de buren  "

        _ = await vm.save()

        #expect(body["notes"] as? String == "Sleutel bij de buren")
    }

    @Test func withoutANoteTheFieldStaysOutOfTheCreateBody() async {
        var body: [String: Any] = [:]
        stubCreate { body = $0 }
        let vm = makeViewModel()
        vm.title = "Kapper"

        _ = await vm.save()

        #expect(body["notes"] == nil)
    }

    // MARK: - dubbele boeking

    @Test func overlapIsDetectedBeforeCreating() async {
        URLProtocolStub.requestHandler = { request in
            #expect(request.httpMethod != "POST")
            let start = PBDate.format(self.day(2026, 8, 3, hour: 9, minute: 30))
            let end = PBDate.format(self.day(2026, 8, 3, hour: 10, minute: 30))
            return (200, Data("""
            {"items":[{"id":"other","owner":"u1","title":"Ander","start":"\(start)","end":"\(end)","all_day":false}],
             "page":1,"perPage":200,"totalItems":1,"totalPages":1}
            """.utf8))
        }
        let vm = makeViewModel(seed: .forHour(9, on: day(2026, 8, 3)))
        vm.title = "Kapper"

        let result = await vm.save()

        #expect(result == nil)
        #expect(vm.overlapEvent?.id == "other")
    }

    @Test func saveConfirmedCreatesWithoutCheckingOverlapAgain() async {
        var postCalled = false
        URLProtocolStub.requestHandler = { request in
            #expect(request.httpMethod != "GET")
            postCalled = true
            return (200, Data(Self.createdRecord.utf8))
        }
        let vm = makeViewModel(seed: .forHour(9, on: day(2026, 8, 3)))
        vm.title = "Kapper"

        let created = await vm.saveConfirmed()

        #expect(postCalled)
        #expect(created?.id == "new1")
        #expect(vm.overlapEvent == nil)
    }

    // MARK: - herinnering + fouten

    @Test func reminderIsScheduledOnTheIdTheServerReturned() async {
        let futureStart = Date().addingTimeInterval(7200)
        URLProtocolStub.requestHandler = { request in
            if request.httpMethod == "GET" { return (200, Data(Self.emptyList.utf8)) }
            return (200, Data("""
            {"id":"new1","owner":"u1","title":"Kapper","start":"\(PBDate.format(futureStart))","end":"\(PBDate.format(futureStart.addingTimeInterval(3600)))","all_day":false}
            """.utf8))
        }
        let scheduler = FakeNotificationScheduler()
        let vm = makeViewModel(scheduler: scheduler)
        vm.title = "Kapper"
        vm.reminderMin = 15

        _ = await vm.save()

        #expect(scheduler.scheduledIdentifiers == ["bovexaflow_reminder_new1"])
    }

    @Test func withoutAReminderNothingIsScheduled() async {
        stubCreate()
        let scheduler = FakeNotificationScheduler()
        let vm = makeViewModel(scheduler: scheduler)
        vm.title = "Kapper"

        _ = await vm.save()

        #expect(scheduler.scheduledIdentifiers.isEmpty)
    }

    @Test func createFailureSetsAlertAndReturnsNil() async {
        URLProtocolStub.requestHandler = { request in
            if request.httpMethod == "GET" { return (200, Data(Self.emptyList.utf8)) }
            return (500, Data("{}".utf8))
        }
        let vm = makeViewModel()
        vm.title = "Kapper"

        let result = await vm.save()

        #expect(result == nil)
        #expect(vm.saveFailedAlert)
        #expect(!vm.isSaving)
    }

    @Test func overlapCheckNetworkFailureSetsAlertInsteadOfCreating() async {
        URLProtocolStub.requestHandler = nil // geen handler → netwerkfout op de check
        let vm = makeViewModel()
        vm.title = "Kapper"

        let result = await vm.save()

        #expect(result == nil)
        #expect(vm.saveFailedAlert)
    }

    // MARK: - sync naar de iPhone Agenda (besluit Ibrahim 21 aug 2026)

    @Test func manualCreateAlsoSyncsToTheDeviceCalendar() async {
        stubCreate()
        let writer = FakeDeviceCalendarWriter()
        let vm = makeViewModel(seed: .forHour(9, on: day(2026, 8, 3)), calendarWriter: writer)
        vm.title = "Kapper"

        let created = await vm.save()

        #expect(created?.id == "new1")
        #expect(writer.createdTitles == ["Kapper"])
    }

    /// Zelfde stille overslag als bij de AI-route: staat de voorkeur uit, dan komt de
    /// afspraak wél op de server maar niet in de iPhone Agenda.
    @Test func syncIsSkippedWhenThePreferenceIsOff() async {
        stubCreate()
        let defaults = UserDefaults(suiteName: "EventEditorCreateModeTests.\(UUID().uuidString)")!
        DeviceCalendarSyncPreference.setEnabled(false, defaults: defaults)
        let writer = FakeDeviceCalendarWriter()
        let vm = makeViewModel(seed: .forHour(9, on: day(2026, 8, 3)), calendarWriter: writer, calendarDefaults: defaults)
        vm.title = "Kapper"

        let created = await vm.save()

        #expect(created?.id == "new1")
        #expect(writer.createdTitles.isEmpty)
    }

    /// Mislukt het aanmaken, dan mag er ook niets in de iPhone Agenda belanden.
    @Test func nothingIsSyncedWhenTheCreateFails() async {
        URLProtocolStub.requestHandler = { request in
            if request.httpMethod == "GET" { return (200, Data(Self.emptyList.utf8)) }
            return (400, Data())
        }
        let writer = FakeDeviceCalendarWriter()
        let vm = makeViewModel(seed: .forHour(9, on: day(2026, 8, 3)), calendarWriter: writer)
        vm.title = "Kapper"

        let created = await vm.save()

        #expect(created == nil)
        #expect(vm.saveFailedAlert)
        #expect(writer.createdTitles.isEmpty)
    }
}
