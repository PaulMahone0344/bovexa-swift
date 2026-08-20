import Testing
import Foundation
@testable import Bovexa

/// PlannerViewModel.confirm() — dubbele-boeking-check (valkuil G), create-volgorde,
/// herinnering, EventKit-sync, en fout-rollback (melding + gesprek behouden). Geport
/// uit confirm() in ~/Desktop/agenda-app/src/hooks/useAiPlanner.ts.
@MainActor
struct PlannerViewModelConfirmTests {
    init() {
        URLProtocolStub.requestHandler = nil
        URLProtocolStub.errorHandler = nil
    }

    private func makeReadyViewModel(
        reminderScheduler: FakeNotificationScheduler = FakeNotificationScheduler(),
        calendarWriter: FakeDeviceCalendarWriter = FakeDeviceCalendarWriter(),
        org: String? = "org1"
    ) -> PlannerViewModel {
        let vm = PlannerViewModel(
            userId: "u1", token: "tok", org: org,
            api: PlannerAPI(session: URLProtocolStub.makeSession()),
            store: PlannerThreadStore(defaults: UserDefaults(suiteName: "confirm.\(UUID().uuidString)")!),
            repository: EventRepository(client: PBClient(session: URLProtocolStub.makeSession())),
            reminderService: ReminderService(scheduler: reminderScheduler),
            deviceCalendarService: DeviceCalendarService(writer: calendarWriter, preferenceDefaults: UserDefaults(suiteName: "confirm-cal.\(UUID().uuidString)")!)
        )
        return vm
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

    /// AppointmentRange.composeDate() bouwt op device-lokale tijd (net als de RN-app);
    /// overlap-fixtures moeten daarom via dezelfde lokale opbouw naar UTC geformatteerd
    /// worden — een hardcoded "...Z"-string zou alleen kloppen op een UTC-host.
    private func isoUTC(date: String = "2026-08-03", time: String) -> String {
        PBDate.format(AppointmentRange.composeDate(date: date, time: time))
    }

    private func stubReadyPlan(title: String = "Tandarts", start: String = "09:00", end: String = "09:30") {
        URLProtocolStub.requestHandler = { _ in
            let json = """
            {"status":"ready","message":"Klaar!","question":null,"options":[],
             "appointments":[{"title":"\(title)","date":"2026-08-03","start":"\(start)","end":"\(end)","category":"body"}]}
            """
            return (200, Data(json.utf8))
        }
    }

    @Test func confirmWithoutOverlapCreatesEventAndClearsConversation() async {
        stubReadyPlan()
        let vm = makeReadyViewModel()
        await vm.sendText("Tandarts morgen 9 uur")
        #expect(vm.ready != nil)

        var createCalled = false
        URLProtocolStub.requestHandler = { request in
            if request.httpMethod == "GET" {
                return (200, Data("""
                {"items":[],"page":1,"perPage":200,"totalItems":0,"totalPages":0}
                """.utf8))
            }
            createCalled = true
            return (200, Data("""
            {"id":"ev1","owner":"u1","title":"Tandarts","start":"2026-08-03 09:00:00.000Z","all_day":false}
            """.utf8))
        }

        await vm.confirm()

        #expect(createCalled)
        #expect(vm.thread.isEmpty)
        #expect(vm.ready == nil)
        #expect(vm.saving == false)
        #expect(vm.overlapEvent == nil)
        #expect(vm.confirmedDate != nil)
    }

    @Test func confirmIncludesChosenLabelInCreatePayload() async {
        stubReadyPlan()
        let vm = makeReadyViewModel(org: "org1")
        await vm.sendText("Tandarts morgen 9 uur")
        vm.label = "l1"

        var postBody: [String: Any] = [:]
        URLProtocolStub.requestHandler = { request in
            if request.httpMethod == "GET" {
                return (200, Data("""
                {"items":[],"page":1,"perPage":200,"totalItems":0,"totalPages":0}
                """.utf8))
            }
            postBody = (try? JSONSerialization.jsonObject(with: self.bodyData(from: request))) as? [String: Any] ?? [:]
            return (200, Data("""
            {"id":"ev1","owner":"u1","title":"Tandarts","start":"2026-08-03 09:00:00.000Z","all_day":false}
            """.utf8))
        }
        await vm.confirm()
        #expect(postBody["label"] as? String == "l1")
    }

    @Test func confirmWithoutOrgOmitsLabelEvenIfSet() async {
        stubReadyPlan()
        let vm = makeReadyViewModel(org: nil)
        await vm.sendText("Tandarts morgen 9 uur")
        vm.label = "l1"

        var postBody: [String: Any] = [:]
        URLProtocolStub.requestHandler = { request in
            if request.httpMethod == "GET" {
                return (200, Data("""
                {"items":[],"page":1,"perPage":200,"totalItems":0,"totalPages":0}
                """.utf8))
            }
            postBody = (try? JSONSerialization.jsonObject(with: self.bodyData(from: request))) as? [String: Any] ?? [:]
            return (200, Data("""
            {"id":"ev1","owner":"u1","title":"Tandarts","start":"2026-08-03 09:00:00.000Z","all_day":false}
            """.utf8))
        }
        await vm.confirm()
        #expect(postBody["label"] == nil)
    }

    /// De starttijd moet ná `now` liggen: ReminderScheduling.fireDate plant bewust
    /// geen herinnering voor een moment dat al voorbij is. Met een vaste datum in
    /// de fixture ging deze test daarom vanzelf rood zodra die dag verstreken was.
    @Test func confirmSchedulesReminderOnlyWhenNonZero() async {
        stubReadyPlan()
        let scheduler = FakeNotificationScheduler()
        let vm = makeReadyViewModel(reminderScheduler: scheduler)
        await vm.sendText("Tandarts morgen 9 uur")
        vm.reminderMin = 15

        let futureStart = PBDate.format(Date().addingTimeInterval(3600))
        URLProtocolStub.requestHandler = { request in
            if request.httpMethod == "GET" {
                return (200, Data("""
                {"items":[],"page":1,"perPage":200,"totalItems":0,"totalPages":0}
                """.utf8))
            }
            return (200, Data("""
            {"id":"ev1","owner":"u1","title":"Tandarts","start":"\(futureStart)","all_day":false}
            """.utf8))
        }
        await vm.confirm()
        #expect(scheduler.scheduledIdentifiers == ["bovexaflow_reminder_ev1"])
    }

    @Test func confirmSyncsToDeviceCalendarWhenEnabled() async {
        stubReadyPlan()
        let writer = FakeDeviceCalendarWriter()
        let vm = makeReadyViewModel(calendarWriter: writer)
        await vm.sendText("Tandarts morgen 9 uur")

        URLProtocolStub.requestHandler = { request in
            if request.httpMethod == "GET" {
                return (200, Data("""
                {"items":[],"page":1,"perPage":200,"totalItems":0,"totalPages":0}
                """.utf8))
            }
            return (200, Data("""
            {"id":"ev1","owner":"u1","title":"Tandarts","start":"2026-08-03 09:00:00.000Z","all_day":false}
            """.utf8))
        }
        await vm.confirm()
        #expect(writer.createdTitles == ["Tandarts"])
    }

    @Test func confirmDetectsOverlapAndDoesNotCreateYet() async {
        stubReadyPlan(start: "09:00", end: "09:30")
        let vm = makeReadyViewModel()
        await vm.sendText("Tandarts morgen 9 uur")

        var createCalled = false
        URLProtocolStub.requestHandler = { request in
            if request.httpMethod == "GET" {
                let json = """
                {"items":[{"id":"existing","owner":"u1","title":"Bestaand","start":"\(self.isoUTC(time: "09:00"))","end":"\(self.isoUTC(time: "09:15"))","all_day":false}],
                 "page":1,"perPage":200,"totalItems":1,"totalPages":1}
                """
                return (200, Data(json.utf8))
            }
            createCalled = true
            return (200, Data("{}".utf8))
        }
        await vm.confirm()

        #expect(vm.overlapEvent?.title == "Bestaand")
        #expect(createCalled == false)
        #expect(vm.saving == false)
        #expect(vm.ready != nil) // gesprek/voorstel blijft staan tijdens de alert
    }

    @Test func cancelOverlapAbortsWithoutCreating() async {
        stubReadyPlan()
        let vm = makeReadyViewModel()
        await vm.sendText("Tandarts morgen 9 uur")

        var createCalled = false
        URLProtocolStub.requestHandler = { request in
            if request.httpMethod == "GET" {
                let json = """
                {"items":[{"id":"existing","owner":"u1","title":"Bestaand","start":"\(self.isoUTC(time: "09:00"))","end":"\(self.isoUTC(time: "09:15"))","all_day":false}],
                 "page":1,"perPage":200,"totalItems":1,"totalPages":1}
                """
                return (200, Data(json.utf8))
            }
            createCalled = true
            return (200, Data("{}".utf8))
        }
        await vm.confirm()
        #expect(vm.overlapEvent != nil)

        vm.cancelOverlap()
        #expect(vm.overlapEvent == nil)
        #expect(createCalled == false)
        #expect(vm.ready != nil)
        #expect(vm.saving == false)
    }

    @Test func proceedPastOverlapContinuesAndCreates() async {
        stubReadyPlan()
        let vm = makeReadyViewModel()
        await vm.sendText("Tandarts morgen 9 uur")

        var createCalled = false
        URLProtocolStub.requestHandler = { request in
            if request.httpMethod == "GET" {
                let json = """
                {"items":[{"id":"existing","owner":"u1","title":"Bestaand","start":"\(self.isoUTC(time: "09:00"))","end":"\(self.isoUTC(time: "09:15"))","all_day":false}],
                 "page":1,"perPage":200,"totalItems":1,"totalPages":1}
                """
                return (200, Data(json.utf8))
            }
            createCalled = true
            return (200, Data("""
            {"id":"ev1","owner":"u1","title":"Tandarts","start":"2026-08-03 09:00:00.000Z","all_day":false}
            """.utf8))
        }
        await vm.confirm()
        #expect(vm.overlapEvent != nil)

        await vm.proceedPastOverlap()
        #expect(createCalled)
        #expect(vm.ready == nil)
        #expect(vm.confirmedDate != nil)
    }

    @Test func createFailureShowsAlertAndKeepsConversation() async {
        stubReadyPlan()
        let vm = makeReadyViewModel()
        await vm.sendText("Tandarts morgen 9 uur")

        URLProtocolStub.requestHandler = { request in
            if request.httpMethod == "GET" {
                return (200, Data("""
                {"items":[],"page":1,"perPage":200,"totalItems":0,"totalPages":0}
                """.utf8))
            }
            return (500, Data("""
            {"message":"Server fout"}
            """.utf8))
        }
        await vm.confirm()

        #expect(vm.saveFailedAlert == true)
        #expect(vm.saving == false)
        #expect(vm.ready != nil)
        #expect(!vm.thread.isEmpty)
    }

    @Test func withoutOrgAssigneesAreDroppedFromCreatePayload() async {
        stubReadyPlan()
        let vm = makeReadyViewModel(org: nil)
        await vm.sendText("Tandarts morgen 9 uur")
        vm.assignee = ["u2"]

        var capturedBody: [String: Any] = [:]
        URLProtocolStub.requestHandler = { request in
            if request.httpMethod == "GET" {
                return (200, Data("""
                {"items":[],"page":1,"perPage":200,"totalItems":0,"totalPages":0}
                """.utf8))
            }
            capturedBody = (try? JSONSerialization.jsonObject(with: self.bodyData(from: request)) as? [String: Any]) ?? [:]
            return (200, Data("""
            {"id":"ev1","owner":"u1","title":"Tandarts","start":"2026-08-03 09:00:00.000Z","all_day":false}
            """.utf8))
        }
        await vm.confirm()

        #expect(capturedBody["org"] as? String == "")
        #expect(capturedBody["visibility"] as? String == "private")
        #expect((capturedBody["assignee"] as? [String])?.isEmpty == true)
    }
}
