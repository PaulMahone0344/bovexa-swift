import Foundation

/// Onthoudt welke herinneringen bij een afspraak horen zolang de server maar één
/// getal bewaart (`reminder_min`, zie MEERDERE-BEDRIJVEN-SERVER.txt). De eerste
/// tijd gaat gewoon naar de server; de tijden daarnaast staan hier, zodat de app
/// ze na een herstart nog kan plannen en bij het verwijderen van een afspraak ook
/// weer kan afzeggen. Zodra het serverveld een lijst wordt, wint dat veld en mag
/// dit weg.
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

    /// Dubbele tijden en nullen eruit, klein naar groot: zo plant de app nooit
    /// twee keer dezelfde melding en is de eerste tijd altijd de dichtstbijzijnde.
    static func opschonen(_ minuten: [Int]) -> [Int] {
        Array(Set(minuten.filter { $0 > 0 })).sorted()
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
