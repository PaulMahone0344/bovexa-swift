import Testing
import Foundation
@testable import Bovexa

final class FakeNotificationScheduler: NotificationScheduling, @unchecked Sendable {
    var authorizationGranted = true
    private(set) var scheduledIdentifiers: [String] = []
    private(set) var canceledIdentifiers: [String] = []

    func currentAuthorizationGranted() async -> Bool { authorizationGranted }
    func requestAuthorization() async -> Bool { authorizationGranted }

    func schedule(identifier: String, title: String, body: String, fireAt: Date) async {
        scheduledIdentifiers.append(identifier)
    }

    func cancel(identifier: String) {
        canceledIdentifiers.append(identifier)
    }

    private(set) var cancelAllCount = 0

    func cancelAll() {
        cancelAllCount += 1
        scheduledIdentifiers.removeAll()
    }
}

struct ReminderServiceTests {
    private func date(_ h: Int, _ min: Int = 0) -> Date {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 8; comps.day = 3; comps.hour = h; comps.minute = min
        return Calendar(identifier: .gregorian).date(from: comps)!
    }

    @Test func scheduleAlwaysCancelsAnyExistingReminderFirst() async {
        let scheduler = FakeNotificationScheduler()
        let service = ReminderService(scheduler: scheduler)
        await service.schedule(eventId: "ev1", title: "T", start: date(10), minutesBefore: 15, now: date(8))
        #expect(scheduler.canceledIdentifiers == ["bovexaflow_reminder_ev1"])
        #expect(scheduler.scheduledIdentifiers == ["bovexaflow_reminder_ev1"])
    }

    @Test func zeroMinutesCancelsButDoesNotSchedule() async {
        let scheduler = FakeNotificationScheduler()
        let service = ReminderService(scheduler: scheduler)
        await service.schedule(eventId: "ev1", title: "T", start: date(10), minutesBefore: 0, now: date(8))
        #expect(scheduler.canceledIdentifiers == ["bovexaflow_reminder_ev1"])
        #expect(scheduler.scheduledIdentifiers.isEmpty)
    }

    @Test func pastFireMomentDoesNotSchedule() async {
        let scheduler = FakeNotificationScheduler()
        let service = ReminderService(scheduler: scheduler)
        await service.schedule(eventId: "ev1", title: "T", start: date(10, 10), minutesBefore: 60, now: date(10))
        #expect(scheduler.scheduledIdentifiers.isEmpty)
    }

    @Test func withoutAuthorizationDoesNotSchedule() async {
        let scheduler = FakeNotificationScheduler()
        scheduler.authorizationGranted = false
        let service = ReminderService(scheduler: scheduler)
        await service.schedule(eventId: "ev1", title: "T", start: date(10), minutesBefore: 15, now: date(8))
        #expect(scheduler.scheduledIdentifiers.isEmpty)
    }

    @Test func cancelUsesEventScopedIdentifier() {
        let scheduler = FakeNotificationScheduler()
        let service = ReminderService(scheduler: scheduler)
        service.cancel(eventId: "ev1")
        #expect(scheduler.canceledIdentifiers == ["bovexaflow_reminder_ev1"])
    }
}

/// Meerdere herinneringen bij één afspraak (punt 15): elke tijd hoort een eigen
/// melding te krijgen, en `cancel` moet ze daarna allemaal terugvinden.
struct ReminderServiceMeerdereTests {
    private func date(_ h: Int, _ min: Int = 0) -> Date {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 8; comps.day = 3; comps.hour = h; comps.minute = min
        return Calendar(identifier: .gregorian).date(from: comps)!
    }

    /// Eigen UserDefaults-suite: de gedeelde store zou tussen tests door blijven
    /// staan en dan telt de annuleer-lijst van een vorige test mee.
    private func store() -> HerinneringStore {
        let defaults = UserDefaults(suiteName: "test_herinneringen_\(UUID().uuidString)")!
        return HerinneringStore(defaults: defaults)
    }

    @Test func everyChosenMinuteGetsItsOwnNotification() async {
        let scheduler = FakeNotificationScheduler()
        let service = ReminderService(scheduler: scheduler, store: store())
        await service.schedule(eventId: "ev1", title: "T", start: date(12), minuten: [60, 15], now: date(8))
        // Klein naar groot: de dichtstbijzijnde houdt de kale identifier, want dat
        // is ook de tijd die als reminder_min op de server staat.
        #expect(scheduler.scheduledIdentifiers == ["bovexaflow_reminder_ev1", "bovexaflow_reminder_ev1_60"])
    }

    @Test func passedMomentsAreSkippedButLaterOnesRemain() async {
        let scheduler = FakeNotificationScheduler()
        let service = ReminderService(scheduler: scheduler, store: store())
        // Start over 30 min: 15 vooraf kan nog, 60 vooraf is al voorbij.
        await service.schedule(eventId: "ev1", title: "T", start: date(10, 30), minuten: [15, 60], now: date(10))
        #expect(scheduler.scheduledIdentifiers == ["bovexaflow_reminder_ev1"])
    }

    @Test func cancelRemovesEveryScheduledIdentifier() async {
        let scheduler = FakeNotificationScheduler()
        let service = ReminderService(scheduler: scheduler, store: store())
        await service.schedule(eventId: "ev1", title: "T", start: date(12), minuten: [15, 60, 1440], now: date(8))
        service.cancel(eventId: "ev1")
        #expect(scheduler.canceledIdentifiers.contains("bovexaflow_reminder_ev1_60"))
        #expect(scheduler.canceledIdentifiers.contains("bovexaflow_reminder_ev1_1440"))
    }

    @Test func duplicatesAndZerosAreDroppedBeforeScheduling() async {
        let scheduler = FakeNotificationScheduler()
        let service = ReminderService(scheduler: scheduler, store: store())
        await service.schedule(eventId: "ev1", title: "T", start: date(12), minuten: [15, 15, 0, 60], now: date(8))
        #expect(scheduler.scheduledIdentifiers == ["bovexaflow_reminder_ev1", "bovexaflow_reminder_ev1_60"])
    }
}
