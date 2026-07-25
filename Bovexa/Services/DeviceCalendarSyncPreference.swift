import Foundation

/// Voorkeur "afspraken ook naar de iPhone Agenda schrijven" — lokaal op het toestel,
/// default AAN. Geport uit isDeviceCalendarSyncEnabled/setDeviceCalendarSyncEnabled in
/// ~/Desktop/agenda-app/src/lib/deviceCalendar.ts. De zichtbare switch komt pas in
/// milestone 6; dit is alvast de opslag die confirm() al respecteert.
enum DeviceCalendarSyncPreference {
    private static let key = "bovexaflow_device_cal_sync"

    static func isEnabled(defaults: UserDefaults = .standard) -> Bool {
        defaults.string(forKey: key) != "off"
    }

    static func setEnabled(_ enabled: Bool, defaults: UserDefaults = .standard) {
        defaults.set(enabled ? "on" : "off", forKey: key)
    }
}
