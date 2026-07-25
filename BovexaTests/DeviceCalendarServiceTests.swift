import Testing
import Foundation
@testable import Bovexa

final class FakeDeviceCalendarWriter: DeviceCalendarWriting, @unchecked Sendable {
    var accessGranted = true
    var calendarId: String? = "cal1"
    var createResult = true
    private(set) var createdTitles: [String] = []

    func requestWriteAccess() async -> Bool { accessGranted }
    func writableCalendarId() -> String? { calendarId }

    func createEvent(_ mapped: DeviceCalendarEventMapper.MappedEvent, calendarId: String) -> Bool {
        createdTitles.append(mapped.title)
        return createResult
    }
}

/// DeviceCalendarService — valkuil H: voorkeur uit/permissie-weigering slaat de sync
/// stil over (afspraak in Bovexa zelf blijft ongemoeid, hier gesimuleerd door gewoon
/// geen event te verwachten).
struct DeviceCalendarServiceTests {
    private func appointment() -> ProposedAppointment {
        ProposedAppointment(title: "Tandarts", date: "2026-08-03", start: "09:00", end: "09:30", category: .body)
    }

    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "DeviceCalendarServiceTests.\(UUID().uuidString)")!
    }

    @Test func syncsWhenPreferenceOnAndAccessGranted() async {
        let writer = FakeDeviceCalendarWriter()
        let service = DeviceCalendarService(writer: writer, preferenceDefaults: makeDefaults())
        let result = await service.sync(appointment())
        #expect(result == true)
        #expect(writer.createdTitles == ["Tandarts"])
    }

    @Test func skipsWhenPreferenceIsOff() async {
        let defaults = makeDefaults()
        DeviceCalendarSyncPreference.setEnabled(false, defaults: defaults)
        let writer = FakeDeviceCalendarWriter()
        let service = DeviceCalendarService(writer: writer, preferenceDefaults: defaults)
        let result = await service.sync(appointment())
        #expect(result == false)
        #expect(writer.createdTitles.isEmpty)
    }

    @Test func skipsSilentlyWhenAccessDenied() async {
        let writer = FakeDeviceCalendarWriter()
        writer.accessGranted = false
        let service = DeviceCalendarService(writer: writer, preferenceDefaults: makeDefaults())
        let result = await service.sync(appointment())
        #expect(result == false)
        #expect(writer.createdTitles.isEmpty)
    }

    @Test func skipsWhenNoWritableCalendarFound() async {
        let writer = FakeDeviceCalendarWriter()
        writer.calendarId = nil
        let service = DeviceCalendarService(writer: writer, preferenceDefaults: makeDefaults())
        let result = await service.sync(appointment())
        #expect(result == false)
    }

    @Test func defaultPreferenceIsOn() {
        #expect(DeviceCalendarSyncPreference.isEnabled(defaults: makeDefaults()) == true)
    }
}
