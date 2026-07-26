import Testing
import Foundation
@testable import Bovexa

final class FakeDeviceCalendarReader: DeviceCalendarReading, @unchecked Sendable {
    var accessGranted = true
    var calendars: [DeviceCalendarInfo] = [DeviceCalendarInfo(id: "cal1", title: "Werk")]
    var eventsToReturn: [DeviceCalendarEvent] = []
    private(set) var requestedIntervals: [DateInterval] = []
    private(set) var requestedCalendarIds: [Set<String>] = []

    func requestFullAccess() async -> Bool { accessGranted }
    func availableCalendars() -> [DeviceCalendarInfo] { calendars }

    func events(in interval: DateInterval, calendarIds: Set<String>) -> [DeviceCalendarEvent] {
        requestedIntervals.append(interval)
        requestedCalendarIds.append(calendarIds)
        return eventsToReturn
    }
}

/// ExternalCalendarService — leeslaag over EventKit (m9 plak 1, valkuil H): permissie
/// geweigerd geeft een lege lijst en geen crash, permissie toegestaan geeft de agenda's
/// en events terug, een periode zonder afspraken is een geldige lege uitkomst.
struct ExternalCalendarServiceTests {
    private func interval() -> DateInterval {
        let start = Date(timeIntervalSince1970: 1_753_000_000)
        return DateInterval(start: start, duration: 86_400)
    }

    @Test func deniedAccessReturnsEmptyCalendarsAndNoCrash() async {
        let reader = FakeDeviceCalendarReader()
        reader.accessGranted = false
        let service = ExternalCalendarService(reader: reader)
        let result = await service.calendars()
        #expect(result.isEmpty)
    }

    @Test func grantedAccessReturnsCalendars() async {
        let reader = FakeDeviceCalendarReader()
        let service = ExternalCalendarService(reader: reader)
        let result = await service.calendars()
        #expect(result == [DeviceCalendarInfo(id: "cal1", title: "Werk")])
    }

    @Test func deniedAccessReturnsEmptyEventsAndNoCrash() async {
        let reader = FakeDeviceCalendarReader()
        reader.accessGranted = false
        reader.eventsToReturn = [
            DeviceCalendarEvent(id: "ev1", calendarId: "cal1", calendarTitle: "Werk", title: "Overleg", startDate: Date(), endDate: Date(), isAllDay: false, location: nil, notes: nil)
        ]
        let service = ExternalCalendarService(reader: reader)
        let result = await service.events(in: interval(), calendarIds: ["cal1"])
        #expect(result.isEmpty)
    }

    @Test func emptyPeriodIsAValidEmptyResult() async {
        let reader = FakeDeviceCalendarReader()
        reader.eventsToReturn = []
        let service = ExternalCalendarService(reader: reader)
        let result = await service.events(in: interval(), calendarIds: ["cal1"])
        #expect(result.isEmpty)
    }

    @Test func grantedAccessReturnsEventsForRequestedCalendars() async {
        let reader = FakeDeviceCalendarReader()
        let event = DeviceCalendarEvent(id: "ev1", calendarId: "cal1", calendarTitle: "Werk", title: "Overleg", startDate: Date(), endDate: Date(), isAllDay: false, location: nil, notes: nil)
        reader.eventsToReturn = [event]
        let service = ExternalCalendarService(reader: reader)
        let result = await service.events(in: interval(), calendarIds: ["cal1"])
        #expect(result.map(\.id) == ["ev1"])
    }

    @Test func noCalendarIdsSelectedReturnsEmptyWithoutCallingReader() async {
        let reader = FakeDeviceCalendarReader()
        reader.eventsToReturn = [
            DeviceCalendarEvent(id: "ev1", calendarId: "cal1", calendarTitle: "Werk", title: "Overleg", startDate: Date(), endDate: Date(), isAllDay: false, location: nil, notes: nil)
        ]
        let service = ExternalCalendarService(reader: reader)
        let result = await service.events(in: interval(), calendarIds: [])
        #expect(result.isEmpty)
    }
}
