import Testing
import Foundation
@testable import Bovexa

struct NoticesSeenStoreTests {
    private func makeDefaults() -> UserDefaults {
        let suiteName = "bovexa-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @Test func lastSeenIsNilBeforeAnyMark() {
        let store = NoticesSeenStore(defaults: makeDefaults())
        #expect(store.lastSeen(userId: "u1") == nil)
    }

    @Test func markSeenPersistsATimestampReadableAsLastSeen() {
        let store = NoticesSeenStore(defaults: makeDefaults())
        let now = Date(timeIntervalSince1970: 12_345)
        store.markSeen(userId: "u1", at: now)
        let seen = store.lastSeen(userId: "u1")
        #expect(seen != nil)
        #expect(abs(seen!.timeIntervalSince1970 - now.timeIntervalSince1970) < 1)
    }

    @Test func seenIsScopedPerUser() {
        let defaults = makeDefaults()
        let store = NoticesSeenStore(defaults: defaults)
        store.markSeen(userId: "u1", at: Date(timeIntervalSince1970: 100))
        #expect(store.lastSeen(userId: "u2") == nil)
    }
}
