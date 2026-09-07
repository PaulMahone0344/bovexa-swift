import Foundation

/// Onthoudt welke lokale meldingen er voor een afspraak op dit toestel staan.
///
/// Sinds het json-veld `reminders` op agenda_events bestaat (7 sep 2026) is dit
/// NIET meer de bewaarplaats van de gekozen tijden — die komen van de server, zie
/// `AgendaEvent.reminders`. Wat overblijft is de annuleer-index: `UNUserNotification`
/// laat zich alleen per identifier afzeggen, en die identifiers bevatten het aantal
/// minuten. Zonder deze lijst weet `ReminderService.cancel` niet welke extra
/// meldingen het ooit heeft ingepland en blijven ze afgaan voor een verwijderde
/// afspraak. Daarom blijft de store staan in plaats van dat hij weggaat: hem
/// schrappen kost méér code (een tweede weg om identifiers terug te vinden), niet
/// minder.
///
/// Bewust geen `@MainActor`: `ReminderService` is een gewone service die ook
/// buiten de hoofdthread gebruikt wordt.
final class HerinneringStore: @unchecked Sendable {
    static let shared = HerinneringStore()

    private static let key = "bovexaflow_herinneringen"

    private let defaults: UserDefaults
    private let lock = NSLock()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Alle tijden van een afspraak, gesorteerd. Leeg = geen herinnering.
    func minuten(voor eventId: String) -> [Int] {
        lock.lock()
        defer { lock.unlock() }
        return laad()[eventId] ?? []
    }

    func zet(_ minuten: [Int], voor eventId: String) {
        guard !eventId.isEmpty else { return }
        lock.lock()
        defer { lock.unlock() }
        var alles = laad()
        let schoon = Self.opschonen(minuten)
        if schoon.isEmpty {
            alles.removeValue(forKey: eventId)
        } else {
            alles[eventId] = schoon
        }
        bewaar(alles)
    }

    func vergeet(_ eventId: String) {
        lock.lock()
        defer { lock.unlock() }
        var alles = laad()
        guard alles.removeValue(forKey: eventId) != nil else { return }
        bewaar(alles)
    }

    /// Bij uitloggen: de herinneringen van de vorige gebruiker horen niet bij de
    /// volgende die op dit toestel inlogt.
    func wisAlles() {
        lock.lock()
        defer { lock.unlock() }
        defaults.removeObject(forKey: Self.key)
    }

    /// Doorgeefluik naar `ReminderOption.opschonen`, zodat bestaande aanroepers
    /// (ReminderService, ReminderChipsView) niet hoeven te weten waar de regel woont.
    static func opschonen(_ minuten: [Int]) -> [Int] {
        ReminderOption.opschonen(minuten)
    }

    private func laad() -> [String: [Int]] {
        guard let data = defaults.data(forKey: Self.key),
              let waarden = try? JSONDecoder().decode([String: [Int]].self, from: data)
        else { return [:] }
        return waarden
    }

    private func bewaar(_ alles: [String: [Int]]) {
        guard let data = try? JSONEncoder().encode(alles) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
