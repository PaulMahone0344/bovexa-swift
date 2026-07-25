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

    @Test func loadWithNothingStoredReturnsEmpty() {
        let store = PlanningNoteStore(defaults: makeDefaults())
        #expect(store.notes.isEmpty)
    }

    @Test func addAppendsNoteToTop() {
        let store = PlanningNoteStore(defaults: makeDefaults())
        let note = store.add(text: "Nieuwe taak")
        #expect(note != nil)
        #expect(store.notes.map(\.id) == [note!.id])
    }

    @Test func addWithEmptyTextReturnsNilAndChangesNothing() {
        let store = PlanningNoteStore(defaults: makeDefaults())
        #expect(store.add(text: "   ") == nil)
        #expect(store.notes.isEmpty)
    }

    @Test func updateReplacesExistingNoteText() {
        let store = PlanningNoteStore(defaults: makeDefaults())
        let note = store.add(text: "Oud")!
        let didUpdate = store.update(id: note.id, text: "Nieuw")
        #expect(didUpdate)
        #expect(store.notes.first?.title == "Nieuw")
    }

    @Test func updateWithUnknownIdReturnsFalse() {
        let store = PlanningNoteStore(defaults: makeDefaults())
        #expect(store.update(id: "onbekend", text: "Iets") == false)
    }

    @Test func toggleFlipsDoneState() {
        let store = PlanningNoteStore(defaults: makeDefaults())
        let note = store.add(text: "Taak")!
        store.toggle(id: note.id)
        #expect(store.notes.first(where: { $0.id == note.id })?.done == true)
        store.toggle(id: note.id)
        #expect(store.notes.first(where: { $0.id == note.id })?.done == false)
    }

    @Test func archiveAndRestore() {
        let store = PlanningNoteStore(defaults: makeDefaults())
        let note = store.add(text: "Taak")!
        store.setArchived(id: note.id, archived: true)
        #expect(store.notes.first(where: { $0.id == note.id })?.archived == true)
        store.setArchived(id: note.id, archived: false)
        #expect(store.notes.first(where: { $0.id == note.id })?.archived == false)
    }

    @Test func deleteRemovesNote() {
        let store = PlanningNoteStore(defaults: makeDefaults())
        let note = store.add(text: "Taak")!
        store.delete(id: note.id)
        #expect(store.notes.isEmpty)
    }

    @Test func savingAndReloadingGivesSameList() {
        let defaults = makeDefaults()
        let store = PlanningNoteStore(defaults: defaults)
        store.add(text: "Eerste taak")
        store.add(text: "Tweede taak\nMet extra tekst")
        let reloaded = PlanningNoteStore(defaults: defaults)
        #expect(reloaded.notes.map(\.title) == store.notes.map(\.title))
        #expect(reloaded.notes.map(\.body) == store.notes.map(\.body))
        #expect(reloaded.notes.map(\.id) == store.notes.map(\.id))
    }

    @Test func mutationsAreScopedToTheirOwnDefaultsSuite() {
        let store1 = PlanningNoteStore(defaults: makeDefaults())
        let store2 = PlanningNoteStore(defaults: makeDefaults())
        store1.add(text: "Alleen in store1")
        #expect(store2.notes.isEmpty)
    }
}
