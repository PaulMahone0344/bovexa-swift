import Foundation

/// Lokale opslag voor "Mijn dagtaken" — UserDefaults, nooit de server (valkuil A). Houdt
/// de actuele lijst in het geheugen en persisteert bij elke mutatie; elke mutatie levert
/// een nieuwe array op, nooit een in-place wijziging.
///
/// De sleutel hangt sinds M11 (plak 3c) aan de userId. Daarvóór deelden alle accounts
/// op één toestel dezelfde lijst: logde een collega in, dan zag die jouw privé-dagtaken
/// en kon ze afvinken of wissen. Alle andere persoonlijke stores (AI-thread,
/// favorieten, notices-seen) waren al per gebruiker.
final class PlanningNoteStore {
    /// De sleutel van vóór M11. Blijft bestaan om éénmalig te migreren; zie
    /// `migrateLegacyIfNeeded`.
    private static let legacyKey = "bovexaflow_planning_notes"

    private static func key(for userId: String) -> String {
        "bovexaflow_planning_notes_\(userId)"
    }

    private let defaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    /// nil = niemand ingelogd. Dan is er niets te tonen en mag er niets geschreven
    /// worden: een mutatie zou anders in de lijst van de vorige gebruiker belanden.
    private var userId: String?
    private(set) var notes: [PlanningNote]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        // Leeg tot `reload(userId:)`: zonder te weten wíé er kijkt is er geen lijst
        // om te tonen en mag er niets geschreven worden.
        notes = []
        userId = nil
    }

    /// Opnieuw uit UserDefaults lezen voor deze gebruiker. Nodig omdat er meerdere
    /// stores naast elkaar bestaan — Dagtaken heeft er een en de kaart op Vandaag
    /// ook. Zonder dit bleef Vandaag de lijst tonen zoals die bij het starten van de
    /// app was, en verdween een net afgevinkte taak daar pas na een herstart.
    func reload(userId: String?) {
        self.userId = userId
        guard let userId else {
            notes = []
            return
        }
        migrateLegacyIfNeeded(to: userId)
        notes = read(from: Self.key(for: userId))
    }

    /// Zet de oude gedeelde lijst één keer over naar de eerste gebruiker die na de
    /// update inlogt, en wist daarna de oude sleutel. Zonder deze stap zijn de
    /// dagtaken van iedere bestaande gebruiker "weg" na de update — de app schrijft
    /// dan naar een sleutel die nog nooit gevuld is. De oude sleutel wissen is even
    /// belangrijk: anders erft elke volgende collega op dit toestel dezelfde lijst.
    private func migrateLegacyIfNeeded(to userId: String) {
        guard let legacy = defaults.data(forKey: Self.legacyKey) else { return }
        if defaults.data(forKey: Self.key(for: userId)) == nil {
            defaults.set(legacy, forKey: Self.key(for: userId))
        }
        defaults.removeObject(forKey: Self.legacyKey)
    }

    private func read(from key: String) -> [PlanningNote] {
        guard let data = defaults.data(forKey: key),
              let stored = try? decoder.decode([PlanningNote].self, from: data) else {
            return []
        }
        return PlanningNoteSorting.sort(stored)
    }

    @discardableResult
    func add(text: String) -> PlanningNote? {
        guard userId != nil, let note = PlanningNoteFactory.make(text: text) else { return nil }
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
        defaults.set(data, forKey: userId.map(Self.key(for:)) ?? Self.legacyKey)
    }
}
