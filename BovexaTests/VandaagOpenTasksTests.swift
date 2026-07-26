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

    @Test func openTasksSkipDoneAndArchived() {
        let defaults = makeDefaults()
        let store = PlanningNoteStore(defaults: defaults)
        store.add(text: "Bonnen inleveren")
        let done = store.add(text: "Banden checken")!
        let archived = store.add(text: "Oude klus")!
        store.toggle(id: done.id)
        store.setArchived(id: archived.id, archived: true)

        let viewModel = makeViewModel(defaults: defaults)
        viewModel.reloadOpenTasks()

        #expect(viewModel.openTasks.map(\.title) == ["Bonnen inleveren"])
    }

    /// Dagtaken en Vandaag hebben elk een eigen store op dezelfde UserDefaults.
    /// Zonder opnieuw inlezen bleef Vandaag de lijst tonen zoals die bij het
    /// starten van de app was.
    @Test func reloadPicksUpChangesFromAnotherStore() {
        let defaults = makeDefaults()
        let viewModel = makeViewModel(defaults: defaults)
        viewModel.reloadOpenTasks()
        #expect(viewModel.openTasks.isEmpty)

        let otherStore = PlanningNoteStore(defaults: defaults)
        otherStore.add(text: "Later toegevoegd")

        viewModel.reloadOpenTasks()

        #expect(viewModel.openTasks.map(\.title) == ["Later toegevoegd"])
    }

    @Test func storeReloadReflectsAToggleFromElsewhere() {
        let defaults = makeDefaults()
        let store = PlanningNoteStore(defaults: defaults)
        let note = store.add(text: "Afvinken")!

        let viewModel = makeViewModel(defaults: defaults)
        viewModel.reloadOpenTasks()
        #expect(viewModel.openTasks.count == 1)

        store.toggle(id: note.id)
        viewModel.reloadOpenTasks()

        #expect(viewModel.openTasks.isEmpty)
    }
}
