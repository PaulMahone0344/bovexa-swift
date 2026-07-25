import Testing
import Foundation
@testable import Bovexa

struct FavoritesStoreTests {
    private func makeDefaults() -> UserDefaults {
        let suiteName = "bovexa-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @Test func loadWithNothingStoredReturnsEmpty() {
        let store = FavoritesStore(defaults: makeDefaults())
        #expect(store.load(userId: "u1").isEmpty)
    }

    @Test func savesAndReloadsPerUser() {
        let defaults = makeDefaults()
        let store = FavoritesStore(defaults: defaults)
        store.save(["a", "b"], userId: "u1")
        #expect(FavoritesStore(defaults: defaults).load(userId: "u1") == ["a", "b"])
    }

    @Test func favoritesAreScopedPerUser() {
        // Zelfde sleutelgedrag als de RN-app: bovexaflow_favoriete_collegas_<userId>.
        let defaults = makeDefaults()
        let store = FavoritesStore(defaults: defaults)
        store.save(["a"], userId: "u1")
        store.save(["b"], userId: "u2")
        #expect(store.load(userId: "u1") == ["a"])
        #expect(store.load(userId: "u2") == ["b"])
    }
}
