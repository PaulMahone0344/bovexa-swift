import Foundation

/// Lokale opslag voor "Mijn dagtaken" — UserDefaults, nooit de server (valkuil A). Houdt
/// de actuele lijst in het geheugen en persisteert bij elke mutatie; elke mutatie levert
/// een nieuwe array op, nooit een in-place wijziging.
final class PlanningNoteStore {
    private static let key = "bovexaflow_planning_notes"

    private let defaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private(set) var notes: [PlanningNote]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        notes = []
        reload()
    }

    /// Opnieuw uit UserDefaults lezen. Nodig omdat er meerdere stores naast elkaar
    /// bestaan — Dagtaken heeft er een en de kaart op Vandaag ook. Zonder dit bleef
    /// Vandaag de lijst tonen zoals die bij het starten van de app was, en verdween
    /// een net afgevinkte taak daar pas na een herstart.
    func reload() {
        guard let data = defaults.data(forKey: Self.key),
              let stored = try? decoder.decode([PlanningNote].self, from: data) else {
            notes = []
            return
        }
        notes = PlanningNoteSorting.sort(stored)
    }

    @discardableResult
    func add(text: String) -> PlanningNote? {
        guard let note = PlanningNoteFactory.make(text: text) else { return nil }
        commit([note] + notes)
        return note
    }

    @discardableResult
    func update(id: String, text: String) -> Bool {
        guard let existing = notes.first(where: { $0.id == id }),
              let updated = PlanningNoteFactory.update(existing, text: text) else { return false }
        commit(notes.map { $0.id == id ? updated : $0 })
        return true
    }

    func toggle(id: String) {
        commit(notes.map { $0.id == id ? $0.withDone(!$0.done) : $0 })
    }

    func setArchived(id: String, archived: Bool) {
        commit(notes.map { $0.id == id ? $0.withArchived(archived) : $0 })
    }

    func delete(id: String) {
        commit(notes.filter { $0.id != id })
    }

    private func commit(_ next: [PlanningNote]) {
        notes = PlanningNoteSorting.sort(next)
        guard let data = try? encoder.encode(notes) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
