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
