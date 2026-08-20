import Testing
import Foundation
@testable import Bovexa

struct PlanningNoteStoreTests {
    private func makeDefaults() -> UserDefaults {
        let suiteName = "bovexa-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    /// Sinds M11 plak 3c hangt de sleutel aan de userId; een store zonder
    /// `reload(userId:)` toont niets en schrijft niets. Dit is de productie-opzet.
    private func makeStore(defaults: UserDefaults, userId: String = "u1") -> PlanningNoteStore {
        let store = PlanningNoteStore(defaults: defaults)
        store.reload(userId: userId)
        return store
    }

    @Test func loadWithNothingStoredReturnsEmpty() {
        let store = makeStore(defaults: makeDefaults())
        #expect(store.notes.isEmpty)
    }

    @Test func addAppendsNoteToTop() {
        let store = makeStore(defaults: makeDefaults())
        let note = store.add(text: "Nieuwe taak")
        #expect(note != nil)
        #expect(store.notes.map(\.id) == [note!.id])
    }

    @Test func addWithEmptyTextReturnsNilAndChangesNothing() {
        let store = makeStore(defaults: makeDefaults())
        #expect(store.add(text: "   ") == nil)
        #expect(store.notes.isEmpty)
    }

    @Test func updateReplacesExistingNoteText() {
        let store = makeStore(defaults: makeDefaults())
        let note = store.add(text: "Oud")!
        let didUpdate = store.update(id: note.id, text: "Nieuw")
        #expect(didUpdate)
        #expect(store.notes.first?.title == "Nieuw")
    }

    @Test func updateWithUnknownIdReturnsFalse() {
        let store = makeStore(defaults: makeDefaults())
        #expect(store.update(id: "onbekend", text: "Iets") == false)
    }

    @Test func toggleFlipsDoneState() {
        let store = makeStore(defaults: makeDefaults())
        let note = store.add(text: "Taak")!
        store.toggle(id: note.id)
        #expect(store.notes.first(where: { $0.id == note.id })?.done == true)
        store.toggle(id: note.id)
        #expect(store.notes.first(where: { $0.id == note.id })?.done == false)
    }

    @Test func toggleDoneSetsCompletedAtAndUndoingClearsIt() {
        let store = makeStore(defaults: makeDefaults())
        let note = store.add(text: "Taak")!
        store.toggle(id: note.id)
        #expect(store.notes.first(where: { $0.id == note.id })?.completedAt != nil)
        store.toggle(id: note.id)
        #expect(store.notes.first(where: { $0.id == note.id })?.completedAt == nil)
    }

    @Test func noteWithoutCompletedAtDecodesAsNilWithoutCrashing() throws {
        // Oude opgeslagen data van vóór dit veld bestond (valkuil).
        let defaults = makeDefaults()
        let legacyJSON = """
        [{"id":"legacy1","title":"Oude taak","body":"","done":true,
          "createdAt":"2026-01-01T09:00:00Z","updatedAt":"2026-01-01T09:00:00Z","archived":false}]
        """.data(using: .utf8)!
        defaults.set(legacyJSON, forKey: "bovexaflow_planning_notes")
        let store = makeStore(defaults: defaults)
        #expect(store.notes.first?.done == true)
        #expect(store.notes.first?.completedAt == nil)
    }

    @Test func archiveAndRestore() {
        let store = makeStore(defaults: makeDefaults())
        let note = store.add(text: "Taak")!
        store.setArchived(id: note.id, archived: true)
        #expect(store.notes.first(where: { $0.id == note.id })?.archived == true)
        store.setArchived(id: note.id, archived: false)
        #expect(store.notes.first(where: { $0.id == note.id })?.archived == false)
    }

    @Test func deleteRemovesNote() {
        let store = makeStore(defaults: makeDefaults())
        let note = store.add(text: "Taak")!
        store.delete(id: note.id)
        #expect(store.notes.isEmpty)
    }

    @Test func savingAndReloadingGivesSameList() {
        let defaults = makeDefaults()
        let store = makeStore(defaults: defaults)
        store.add(text: "Eerste taak")
        store.add(text: "Tweede taak\nMet extra tekst")
        let reloaded = makeStore(defaults: defaults)
        #expect(reloaded.notes.map(\.title) == store.notes.map(\.title))
        #expect(reloaded.notes.map(\.body) == store.notes.map(\.body))
        #expect(reloaded.notes.map(\.id) == store.notes.map(\.id))
    }

    @Test func mutationsAreScopedToTheirOwnDefaultsSuite() {
        let store1 = makeStore(defaults: makeDefaults())
        let store2 = makeStore(defaults: makeDefaults())
        store1.add(text: "Alleen in store1")
        #expect(store2.notes.isEmpty)
    }

    // MARK: - Sleutel per gebruiker + migratie (M11 plak 3c)

    private static let legacyKey = "bovexaflow_planning_notes"

    /// Schrijft rechtstreeks op de oude gedeelde sleutel — precies wat de vorige
    /// versie van de app achterliet. Niet via de store, want die schrijft sinds
    /// plak 3c alleen nog per gebruiker.
    private func seedLegacyNotes(_ titles: [String], in defaults: UserDefaults) {
        let now = Date()
        let notes = titles.enumerated().map { index, title in
            PlanningNote(
                id: "legacy-\(index)", title: title, body: "", done: false,
                createdAt: now.addingTimeInterval(-Double(index)),
                updatedAt: now.addingTimeInterval(-Double(index)), archived: false
            )
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        defaults.set(try! encoder.encode(notes), forKey: Self.legacyKey)
    }

    /// Zonder deze migratie zijn de dagtaken van iedere bestaande gebruiker weg na
    /// de update: de app schrijft dan naar een sleutel die nog nooit gevuld is.
    @Test func firstLoadForAUserMigratesTheOldSharedKey() {
        let defaults = makeDefaults()
        seedLegacyNotes(["Van vóór de update"], in: defaults)

        let store = PlanningNoteStore(defaults: defaults)
        store.reload(userId: "u1")

        #expect(store.notes.map(\.title) == ["Van vóór de update"])
        // Eenmalig: de oude sleutel is daarna leeg, anders erft de volgende
        // gebruiker op dit toestel dezelfde lijst.
        #expect(defaults.data(forKey: Self.legacyKey) == nil)
    }

    @Test func migrationRunsOnlyOnceAndDoesNotOverwriteLaterEdits() {
        let defaults = makeDefaults()
        seedLegacyNotes(["Oud"], in: defaults)

        let first = PlanningNoteStore(defaults: defaults)
        first.reload(userId: "u1")
        first.add(text: "Nieuw")

        let second = PlanningNoteStore(defaults: defaults)
        second.reload(userId: "u1")
        #expect(second.notes.map(\.title) == ["Nieuw", "Oud"])
    }

    @Test func twoUsersOnTheSameDeviceKeepSeparateNotes() {
        let defaults = makeDefaults()
        let store = PlanningNoteStore(defaults: defaults)

        store.reload(userId: "u1")
        store.add(text: "Privé van u1")

        store.reload(userId: "u2")
        #expect(store.notes.isEmpty)
        store.add(text: "Privé van u2")

        store.reload(userId: "u1")
        #expect(store.notes.map(\.title) == ["Privé van u1"])
    }

    @Test func theSecondUserDoesNotInheritTheMigratedLegacyNotes() {
        let defaults = makeDefaults()
        seedLegacyNotes(["Van de eerste gebruiker"], in: defaults)

        let store = PlanningNoteStore(defaults: defaults)
        store.reload(userId: "u1")
        #expect(store.notes.count == 1)

        store.reload(userId: "u2")
        #expect(store.notes.isEmpty)
    }

    @Test func reloadWithNilUserIdEmptiesTheList() {
        let defaults = makeDefaults()
        let store = PlanningNoteStore(defaults: defaults)
        store.reload(userId: "u1")
        store.add(text: "Van u1")

        store.reload(userId: nil)
        #expect(store.notes.isEmpty)
        // En uitgelogd schrijven mag niet stiekem in de lijst van u1 belanden.
        #expect(store.add(text: "Zonder gebruiker") == nil)
        store.reload(userId: "u1")
        #expect(store.notes.map(\.title) == ["Van u1"])
    }
}
