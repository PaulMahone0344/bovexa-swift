import Testing
import Foundation
@testable import Bovexa

/// Valkuil C: toegewezenen horen ALTIJD ook in viewers.
struct EventViewersTests {
    @Test func unionAddsAssigneesNotAlreadyInViewers() {
        let result = EventViewers.union(["u1"], assignees: ["u2"])
        #expect(result == ["u1", "u2"])
    }

    @Test func unionDeduplicatesOverlappingIds() {
        let result = EventViewers.union(["u1", "u2"], assignees: ["u2"])
        #expect(result == ["u1", "u2"])
    }

    @Test func unionOfEmptyListsIsEmpty() {
        #expect(EventViewers.union([], assignees: []).isEmpty)
    }
}
