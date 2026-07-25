import Testing
import Foundation
@testable import Bovexa

/// AfwezigViewModel — pick-logica (1e tik = vanaf, 2e = t/m), max 31 dagen, en save()
/// (per dag create, org-afhankelijk calendar/visibility). Geport uit afwezig.tsx.
@MainActor
struct AfwezigViewModelTests {
    init() {
        URLProtocolStub.requestHandler = nil
        URLProtocolStub.errorHandler = nil
    }

    private func day(_ d: Int, _ m: Int = 8, _ y: Int = 2026) -> Date {
        var comps = DateComponents()
        comps.year = y; comps.month = m; comps.day = d
        return Calendar(identifier: .gregorian).date(from: comps)!
    }

    private func makeViewModel(org: String? = "org1", today: Date? = nil) -> AfwezigViewModel {
        AfwezigViewModel(
            userId: "u1", org: org, token: "tok",
            repository: EventRepository(client: PBClient(session: URLProtocolStub.makeSession())),
            today: today ?? day(1)
        )
    }

    // MARK: - pickDay

    @Test func firstTapSetsFromOnly() {
        let vm = makeViewModel()
        vm.pickDay(day(3))
        #expect(vm.range == [day(3, 8)].map { AfwezigRange.atNoon($0) })
    }

    @Test func secondTapAfterFromSetsTo() {
        let vm = makeViewModel()
        vm.pickDay(day(3))
        vm.pickDay(day(5))
        #expect(vm.range.count == 3)
    }

    /// Tikken vóór "vanaf" schuift alleen "vanaf" terug — "tot" blijft ongezet
    /// (nog geen periode), exact zoals pick() in afwezig.tsx.
    @Test func secondTapBeforeFromShiftsFromBackWithoutSettingTo() {
        let vm = makeViewModel()
        vm.pickDay(day(10))
        vm.pickDay(day(5))
        #expect(vm.range.count == 1)
        #expect(vm.isInRange(day(5)))
        #expect(!vm.isInRange(day(10)))
    }

    @Test func thirdTapAfterShiftedFromCompletesRange() {
        let vm = makeViewModel()
        vm.pickDay(day(10))
        vm.pickDay(day(5))
        vm.pickDay(day(10))
        #expect(vm.range.count == 6) // 5 t/m 10
        #expect(vm.isInRange(day(5)))
        #expect(vm.isInRange(day(10)))
    }

    @Test func tapAfterCompletedRangeStartsNewSelection() {
        let vm = makeViewModel()
        vm.pickDay(day(3))
        vm.pickDay(day(5))
        vm.pickDay(day(20))
        #expect(vm.range.count == 1)
        #expect(vm.isInRange(day(20)))
        #expect(!vm.isInRange(day(3)))
    }

    @Test func isInRangeIsFalseWithoutSelection() {
        let vm = makeViewModel()
        #expect(vm.isInRange(day(3)) == false)
    }

    // MARK: - tooLong / canSave

    @Test func canSaveIsFalseWithoutSelection() {
        let vm = makeViewModel()
        #expect(vm.canSave == false)
    }

    @Test func canSaveIsTrueWithValidSelection() {
        let vm = makeViewModel()
        vm.pickDay(day(3))
        #expect(vm.canSave == true)
        #expect(vm.tooLong == false)
    }

    @Test func canSaveIsFalseWhenTooLong() {
        let vm = makeViewModel()
        vm.pickDay(day(1))
        vm.pickDay(day(1, 9)) // 32 dagen
        #expect(vm.tooLong == true)
        #expect(vm.canSave == false)
    }

    // MARK: - save()

    @Test func saveCreatesOneRecordPerDayWithOrgDerivedFields() async {
        let vm = makeViewModel(org: "org1")
        vm.pickDay(day(3))
        vm.pickDay(day(5))

        var createdBodies: [[String: Any]] = []
        URLProtocolStub.requestHandler = { request in
            let data = self.bodyData(from: request)
            createdBodies.append((try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:])
            return (200, Data("""
            {"id":"ev1","owner":"u1","title":"Vakantie","start":"2026-08-03 12:00:00.000Z","all_day":true}
            """.utf8))
        }
        await vm.save()

        #expect(createdBodies.count == 3)
        #expect(createdBodies.allSatisfy { $0["category"] as? String == "afwezig" })
        #expect(createdBodies.allSatisfy { $0["calendar"] as? String == "work" })
        #expect(createdBodies.allSatisfy { $0["visibility"] as? String == "company" })
        #expect(createdBodies.allSatisfy { $0["org"] as? String == "org1" })
        #expect(createdBodies.allSatisfy { $0["raw_input"] as? String == "afwezig: vakantie" })
        #expect(vm.savedAlertMessage != nil)
    }

    @Test func saveWithoutOrgUsesPrivateCalendarAndVisibility() async {
        let vm = makeViewModel(org: nil)
        vm.pickDay(day(3))

        var capturedBody: [String: Any] = [:]
        URLProtocolStub.requestHandler = { request in
            capturedBody = (try? JSONSerialization.jsonObject(with: self.bodyData(from: request)) as? [String: Any]) ?? [:]
            return (200, Data("""
            {"id":"ev1","owner":"u1","title":"Vakantie","start":"2026-08-03 12:00:00.000Z","all_day":true}
            """.utf8))
        }
        await vm.save()

        #expect(capturedBody["calendar"] as? String == "private")
        #expect(capturedBody["visibility"] as? String == "private")
        #expect(capturedBody["org"] as? String == "")
    }

    @Test func saveSingleDayMessageMentionsSingleDate() async {
        let vm = makeViewModel()
        vm.pickDay(day(3))
        URLProtocolStub.requestHandler = { _ in
            (200, Data("""
            {"id":"ev1","owner":"u1","title":"Vakantie","start":"2026-08-03 12:00:00.000Z","all_day":true}
            """.utf8))
        }
        await vm.save()
        #expect(vm.savedAlertMessage == "Vakantie ingepland op 3 aug.")
    }

    @Test func saveRangeMessageMentionsFromAndTo() async {
        let vm = makeViewModel()
        vm.pickDay(day(3))
        vm.pickDay(day(5))
        URLProtocolStub.requestHandler = { _ in
            (200, Data("""
            {"id":"ev1","owner":"u1","title":"Vakantie","start":"2026-08-03 12:00:00.000Z","all_day":true}
            """.utf8))
        }
        await vm.save()
        #expect(vm.savedAlertMessage == "Vakantie ingepland van 3 aug t/m 5 aug.")
    }

    @Test func saveFailureSetsAlertAndKeepsSelection() async {
        let vm = makeViewModel()
        vm.pickDay(day(3))
        URLProtocolStub.requestHandler = { _ in (500, Data()) }
        await vm.save()
        #expect(vm.saveFailedAlert == true)
        #expect(vm.saving == false)
        #expect(vm.range.count == 1) // selectie blijft staan, gebruiker kan opnieuw proberen
    }

    @Test func saveWhenCannotSaveDoesNothing() async {
        let vm = makeViewModel()
        URLProtocolStub.requestHandler = { _ in
            Issue.record("mocht geen netwerkverzoek doen")
            return (500, Data())
        }
        await vm.save()
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
}
