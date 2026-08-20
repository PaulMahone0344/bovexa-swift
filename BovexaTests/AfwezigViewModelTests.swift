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

    private func day(_ d: Int, _ m: Int = 8, _ y: Int = 2026, hour: Int = 0) -> Date {
        var comps = DateComponents()
        comps.year = y; comps.month = m; comps.day = d; comps.hour = hour
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

    // MARK: - reason "Anders" (klantverzoek 26 juli)

    @Test func canSaveIsFalseWhenAndersHasNoToelichting() {
        let vm = makeViewModel()
        vm.pickDay(day(3))
        vm.reason = .anders
        #expect(vm.canSave == false)
    }

    @Test func canSaveIsFalseWhenAndersToelichtingIsOnlyWhitespace() {
        let vm = makeViewModel()
        vm.pickDay(day(3))
        vm.reason = .anders
        vm.andersToelichting = "   "
        #expect(vm.canSave == false)
    }

    @Test func canSaveIsTrueWhenAndersHasToelichting() {
        let vm = makeViewModel()
        vm.pickDay(day(3))
        vm.reason = .anders
        vm.andersToelichting = "Tandarts"
        #expect(vm.canSave == true)
    }

    @Test func saveWithAndersUsesToelichtingAsTitleButRawInputStaysGeneric() async {
        let vm = makeViewModel(org: "org1")
        vm.pickDay(day(3))
        vm.reason = .anders
        vm.andersToelichting = "Tandarts"

        var createdBodies: [[String: Any]] = []
        URLProtocolStub.requestHandler = { request in
            let data = self.bodyData(from: request)
            createdBodies.append((try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:])
            return (200, Data("""
            {"id":"ev1","owner":"u1","title":"Tandarts","start":"2026-08-03 12:00:00.000Z","all_day":true}
            """.utf8))
        }
        await vm.save()

        #expect(createdBodies.count == 1)
        #expect(createdBodies[0]["title"] as? String == "Tandarts")
        #expect(createdBodies[0]["raw_input"] as? String == "afwezig: anders")
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

    // MARK: - heleDag (m7 plak 5)

    @Test func heleDagDefaultsToTrue() {
        let vm = makeViewModel()
        #expect(vm.heleDag == true)
    }

    @Test func effectiveHeleDagIsForcedTrueForMultiDaySelectionEvenIfToggledOff() {
        let vm = makeViewModel()
        vm.pickDay(day(3))
        vm.pickDay(day(5))
        vm.heleDag = false
        #expect(vm.isSingleDaySelection == false)
        #expect(vm.effectiveHeleDag == true)
    }

    @Test func effectiveHeleDagRespectsToggleForSingleDaySelection() {
        let vm = makeViewModel()
        vm.pickDay(day(3))
        vm.heleDag = false
        #expect(vm.isSingleDaySelection == true)
        #expect(vm.effectiveHeleDag == false)
    }

    @Test func canSaveIsFalseWhenPartialDayEndIsBeforeStart() {
        let vm = makeViewModel()
        vm.pickDay(day(3))
        vm.heleDag = false
        vm.startTime = day(3, hour: 17)
        vm.endTime = day(3, hour: 9)
        #expect(vm.canSave == false)
    }

    @Test func canSaveIsTrueWhenPartialDayEndIsAfterStart() {
        let vm = makeViewModel()
        vm.pickDay(day(3))
        vm.heleDag = false
        vm.startTime = day(3, hour: 9)
        vm.endTime = day(3, hour: 17)
        #expect(vm.canSave == true)
    }

    @Test func savePartialDaySendsAllDayFalseWithStartAndEnd() async {
        let vm = makeViewModel()
        vm.pickDay(day(3))
        vm.heleDag = false
        vm.startTime = day(3, hour: 13)
        vm.endTime = day(3, hour: 17)

        let expectedStart = PBDate.format(AfwezigRange.combine(day: AfwezigRange.atNoon(day(3)), time: vm.startTime))
        let expectedEnd = PBDate.format(AfwezigRange.combine(day: AfwezigRange.atNoon(day(3)), time: vm.endTime))

        var capturedBody: [String: Any] = [:]
        URLProtocolStub.requestHandler = { request in
            capturedBody = (try? JSONSerialization.jsonObject(with: self.bodyData(from: request)) as? [String: Any]) ?? [:]
            return (200, Data("""
            {"id":"ev1","owner":"u1","title":"Vakantie","start":"\(expectedStart)","end":"\(expectedEnd)","all_day":false}
            """.utf8))
        }
        await vm.save()

        #expect(capturedBody["all_day"] as? Bool == false)
        #expect(capturedBody["start"] as? String == expectedStart)
        #expect(capturedBody["end"] as? String == expectedEnd)
    }

    @Test func saveMultiDayIgnoresHeleDagToggleAndStaysAllDay() async {
        let vm = makeViewModel()
        vm.pickDay(day(3))
        vm.pickDay(day(5))
        vm.heleDag = false

        var createdBodies: [[String: Any]] = []
        URLProtocolStub.requestHandler = { request in
            createdBodies.append((try? JSONSerialization.jsonObject(with: self.bodyData(from: request)) as? [String: Any]) ?? [:])
            return (200, Data("""
            {"id":"ev1","owner":"u1","title":"Vakantie","start":"2026-08-03 12:00:00.000Z","all_day":true}
            """.utf8))
        }
        await vm.save()

        #expect(createdBodies.count == 3)
        #expect(createdBodies.allSatisfy { $0["all_day"] as? Bool == true })
        #expect(createdBodies.allSatisfy { $0["end"] == nil })
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

    // MARK: - Hervatten na een half gelukte reeks (M11 plak 4c)

    /// Faalde dag 3 van 5, dan stonden 1 en 2 al op de server: "opnieuw" maakte ze
    /// een tweede keer aan.
    @Test func retryAfterAPartialFailureDoesNotDuplicateTheDaysThatSucceeded() async {
        let vm = makeViewModel()
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        vm.pickDay(start)
        vm.pickDay(start.addingTimeInterval(2 * 24 * 60 * 60)) // drie dagen

        let counter = CreateCounter()
        URLProtocolStub.requestHandler = { _ in
            let n = counter.bump()
            // Eerste twee lukken, de derde faalt.
            if n <= 2 {
                return (200, Data("""
                {"id":"e\(n)","owner":"u1","title":"Vakantie","start":"2026-08-20 00:00:00.000Z","all_day":true}
                """.utf8))
            }
            return (500, Data("{}".utf8))
        }
        await vm.save()
        #expect(vm.saveFailedAlert)
        #expect(counter.count == 3)

        // Tweede poging: alleen de derde dag hoort nog aangemaakt te worden.
        vm.saveFailedAlert = false
        counter.reset()
        URLProtocolStub.requestHandler = { _ in
            _ = counter.bump()
            return (200, Data("""
            {"id":"e3","owner":"u1","title":"Vakantie","start":"2026-08-22 00:00:00.000Z","all_day":true}
            """.utf8))
        }
        await vm.save()

        #expect(counter.count == 1)
        #expect(vm.savedAlertMessage != nil)
    }

    /// Een andere periode kiezen is een nieuwe reeks; het hervat-punt hoort dan weg.
    @Test func pickingAnotherPeriodResetsTheResumePoint() async {
        let vm = makeViewModel()
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        vm.pickDay(start)
        vm.pickDay(start.addingTimeInterval(24 * 60 * 60))

        let counter = CreateCounter()
        URLProtocolStub.requestHandler = { _ in
            let n = counter.bump()
            if n == 1 {
                return (200, Data("""
                {"id":"e1","owner":"u1","title":"Vakantie","start":"2026-08-20 00:00:00.000Z","all_day":true}
                """.utf8))
            }
            return (500, Data("{}".utf8))
        }
        await vm.save()
        #expect(vm.saveFailedAlert)

        // Nieuwe periode van twee dagen: beide moeten opnieuw aangemaakt worden.
        vm.pickDay(start.addingTimeInterval(10 * 24 * 60 * 60))
        vm.pickDay(start.addingTimeInterval(11 * 24 * 60 * 60))
        vm.saveFailedAlert = false
        counter.reset()
        URLProtocolStub.requestHandler = { _ in
            _ = counter.bump()
            return (200, Data("""
            {"id":"x","owner":"u1","title":"Vakantie","start":"2026-08-30 00:00:00.000Z","all_day":true}
            """.utf8))
        }
        await vm.save()

        #expect(counter.count == 2)
    }

}

/// Thread-safe teller voor de @Sendable request-handler van URLProtocolStub.
final class CreateCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    @discardableResult
    func bump() -> Int {
        lock.lock(); defer { lock.unlock() }
        value += 1
        return value
    }

    func reset() { lock.lock(); value = 0; lock.unlock() }
    var count: Int { lock.lock(); defer { lock.unlock() }; return value }
}
