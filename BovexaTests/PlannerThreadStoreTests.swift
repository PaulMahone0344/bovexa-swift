import Testing
import Foundation
@testable import Bovexa

/// Valkuil F: max 40 thread-items / 30 API-beurten bij het bewaren, per gebruiker.
struct PlannerThreadStoreTests {
    private func makeStore() -> (PlannerThreadStore, UserDefaults) {
        let suiteName = "PlannerThreadStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return (PlannerThreadStore(defaults: defaults), defaults)
    }

    @Test func loadReturnsNilWhenNothingSaved() {
        let (store, _) = makeStore()
        #expect(store.load(userId: "u1") == nil)
    }

    @Test func saveThenLoadRoundTripsConversation() {
        let (store, _) = makeStore()
        let conversation = SavedConversation(
            thread: [ThreadItem(id: "1", kind: .user, text: "Morgen tandarts")],
            api: [ChatTurn(role: .user, content: "Morgen tandarts")],
            raw: "Morgen tandarts"
        )
        store.save(conversation, userId: "u1")
        #expect(store.load(userId: "u1") == conversation)
    }

    @Test func saveTrimsThreadToMaxItems() {
        let (store, _) = makeStore()
        let thread = (1...50).map { ThreadItem(id: "\($0)", kind: .user, text: "bericht \($0)") }
        store.save(SavedConversation(thread: thread, api: [], raw: ""), userId: "u1")
        let loaded = store.load(userId: "u1")
        #expect(loaded?.thread.count == PlannerThreadStore.maxThreadItems)
        #expect(loaded?.thread.first?.id == "11") // laatste 40 van 50
        #expect(loaded?.thread.last?.id == "50")
    }

    @Test func saveTrimsApiHistoryToMaxTurns() {
        let (store, _) = makeStore()
        let api = (1...40).map { ChatTurn(role: .user, content: "beurt \($0)") }
        store.save(SavedConversation(thread: [], api: api, raw: ""), userId: "u1")
        let loaded = store.load(userId: "u1")
        #expect(loaded?.api.count == PlannerThreadStore.maxApiTurns)
        #expect(loaded?.api.first?.content == "beurt 11")
    }

    @Test func clearRemovesSavedConversation() {
        let (store, _) = makeStore()
        store.save(SavedConversation(thread: [ThreadItem(id: "1", kind: .user, text: "T")], api: [], raw: "T"), userId: "u1")
        store.clear(userId: "u1")
        #expect(store.load(userId: "u1") == nil)
    }

    @Test func conversationsAreIsolatedPerUser() {
        let (store, _) = makeStore()
        store.save(SavedConversation(thread: [ThreadItem(id: "1", kind: .user, text: "Van u1")], api: [], raw: ""), userId: "u1")
        #expect(store.load(userId: "u2") == nil)
    }
}
