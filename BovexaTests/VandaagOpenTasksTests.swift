import Testing
import Foundation
@testable import Bovexa

/// Kaart "Dagtaken" op Vandaag: alleen wat nog te doen is.
@MainActor
struct VandaagOpenTasksTests {
    private func makeDefaults() -> UserDefaults {
        let suiteName = "bovexa-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func makeViewModel(defaults: UserDefaults) -> VandaagViewModel {
        VandaagViewModel(planningStore: PlanningNoteStore(defaults: defaults), defaults: defaults)
    }

    /// Sinds M11 plak 3c hangt de sleutel aan de userId: een store zonder
    /// `reload(userId:)` toont niets en schrijft niets.
    private func makeStore(defaults: UserDefaults, userId: String = "u1") -> PlanningNoteStore {
        let store = PlanningNoteStore(defaults: defaults)
        store.reload(userId: userId)
        return store
    }

    @Test func openTasksSkipDoneAndArchived() {
        let defaults = makeDefaults()
        let store = makeStore(defaults: defaults)
        store.add(text: "Bonnen inleveren")
        let done = store.add(text: "Banden checken")!
        let archived = store.add(text: "Oude klus")!
        store.toggle(id: done.id)
        store.setArchived(id: archived.id, archived: true)

        let viewModel = makeViewModel(defaults: defaults)
        viewModel.reloadOpenTasks(userId: "u1")

        #expect(viewModel.openTasks.map(\.title) == ["Bonnen inleveren"])
    }

    /// Dagtaken en Vandaag hebben elk een eigen store op dezelfde UserDefaults.
    /// Zonder opnieuw inlezen bleef Vandaag de lijst tonen zoals die bij het
    /// starten van de app was.
    @Test func reloadPicksUpChangesFromAnotherStore() {
        let defaults = makeDefaults()
        let viewModel = makeViewModel(defaults: defaults)
        viewModel.reloadOpenTasks(userId: "u1")
        #expect(viewModel.openTasks.isEmpty)

        let otherStore = makeStore(defaults: defaults)
        otherStore.add(text: "Later toegevoegd")

        viewModel.reloadOpenTasks(userId: "u1")

        #expect(viewModel.openTasks.map(\.title) == ["Later toegevoegd"])
    }

    @Test func storeReloadReflectsAToggleFromElsewhere() {
        let defaults = makeDefaults()
        let store = makeStore(defaults: defaults)
        let note = store.add(text: "Afvinken")!

        let viewModel = makeViewModel(defaults: defaults)
        viewModel.reloadOpenTasks(userId: "u1")
        #expect(viewModel.openTasks.count == 1)

        store.toggle(id: note.id)
        viewModel.reloadOpenTasks(userId: "u1")

        #expect(viewModel.openTasks.isEmpty)
    }
}
