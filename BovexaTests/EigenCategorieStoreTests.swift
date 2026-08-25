import Testing
import Foundation
@testable import Bovexa

@MainActor
struct EigenCategorieStoreTests {
    private func makeDefaults() -> UserDefaults {
        let suiteName = "bovexa-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @Test func startsEmpty() {
        #expect(EigenCategorieStore(defaults: makeDefaults()).namen.isEmpty)
    }

    /// Volgorde van toevoegen blijft staan: het formulier zet "Anders" achteraan,
    /// dus de nieuwste knop hoort er links naast te komen.
    @Test func keepsTheOrderTheyWereAdded() {
        let store = EigenCategorieStore(defaults: makeDefaults())

        store.voegToe("Studie")
        store.voegToe("Klussen")

        #expect(store.namen == ["Studie", "Klussen"])
    }

    @Test func survivesARestart() {
        let defaults = makeDefaults()
        EigenCategorieStore(defaults: defaults).voegToe("Studie")

        #expect(EigenCategorieStore(defaults: defaults).namen == ["Studie"])
    }

    /// Zonder trim werd " Studie" een tweede knop naast "Studie".
    @Test func trimsWhitespaceAndRefusesEmptyNames() {
        let store = EigenCategorieStore(defaults: makeDefaults())

        #expect(store.voegToe("  Studie  ") == "Studie")
        #expect(store.voegToe("   ") == nil)
        #expect(store.namen == ["Studie"])
    }

    /// Hoofdletterongevoelig, en ook tegen de vaste knoppen: anders staat er een
    /// tweede "Sport" die iets anders doet dan de echte.
    @Test func refusesDuplicates() {
        let store = EigenCategorieStore(defaults: makeDefaults())
        store.voegToe("Studie")

        #expect(store.voegToe("studie") == nil)
        #expect(store.voegToe("Sport") == nil)
        #expect(store.voegToe("werk") == nil)
        #expect(store.namen == ["Studie"])
    }

    @Test func cutsNamesThatAreTooLong() {
        let store = EigenCategorieStore(defaults: makeDefaults())

        let bewaard = store.voegToe(String(repeating: "a", count: 40))

        #expect(bewaard?.count == EigenCategorieStore.maxTekens)
    }

    @Test func stopsAtTheMaximum() {
        let store = EigenCategorieStore(defaults: makeDefaults())
        for i in 0..<EigenCategorieStore.maxAantal { store.voegToe("Cat\(i)") }

        #expect(store.voegToe("Nog een") == nil)
        #expect(store.namen.count == EigenCategorieStore.maxAantal)
    }

    @Test func removesByName() {
        let store = EigenCategorieStore(defaults: makeDefaults())
        store.voegToe("Studie")
        store.voegToe("Klussen")

        store.verwijder("studie")

        #expect(store.namen == ["Klussen"])
    }
}
