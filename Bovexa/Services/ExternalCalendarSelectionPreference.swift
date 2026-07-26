import Foundation

/// Welke agenda's van het toestel je in Bovexa Flow wilt zien — lokaal op het toestel,
/// niet in het account (m9 valkuil I: geen schemawijziging, geen server-opslag).
/// Standaard niets geselecteerd, net als de dagtaken uit m4.
enum ExternalCalendarSelectionPreference {
    private static let key = "bovexaflow_external_calendars"

    static func selectedIds(defaults: UserDefaults = .standard) -> Set<String> {
        Set(defaults.stringArray(forKey: key) ?? [])
    }

    static func setSelectedIds(_ ids: Set<String>, defaults: UserDefaults = .standard) {
        defaults.set(Array(ids), forKey: key)
    }
}
