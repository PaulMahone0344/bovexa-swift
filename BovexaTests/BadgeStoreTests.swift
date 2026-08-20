import Testing
import Foundation
@testable import Bovexa

/// M11 plak 6b (besluit Ibrahim 19 aug): cijfer op de Profiel-tab = open
/// toewijzingen + ongelezen mededelingen.
@MainActor
struct BadgeStoreTests {
    @Test func aFreshStoreShowsNothing() {
        #expect(BadgeStore().total == 0)
    }

    @Test func theTotalIsAssignmentsPlusNotices() {
        let store = BadgeStore()
        store.setPendingAssignments(2)
        store.setUnreadNotices(1)
        #expect(store.total == 3)
    }

    /// 0 betekent geen badge; SwiftUI verbergt `.badge(0)` zelf.
    @Test func answeringTheLastAssignmentBringsTheBadgeBackToZero() {
        let store = BadgeStore()
        store.setPendingAssignments(1)
        #expect(store.total == 1)

        store.setPendingAssignments(0)
        #expect(store.total == 0)
    }

    /// De meldingen-sheet markeert alles als gezien; het cijfer hoort dan meteen
    /// te kloppen, niet pas na de volgende load.
    @Test func readingTheNoticesClearsOnlyTheNoticePart() {
        let store = BadgeStore()
        store.setPendingAssignments(2)
        store.setUnreadNotices(1)

        store.clearNotices()

        #expect(store.unreadNotices == 0)
        #expect(store.pendingAssignments == 2)
        #expect(store.total == 2)
    }

    /// Verdedigend: een negatief cijfer op een tabbalk is onzin.
    @Test func negativeCountsAreClampedToZero() {
        let store = BadgeStore()
        store.setPendingAssignments(-3)
        store.setUnreadNotices(-1)
        #expect(store.total == 0)
    }
}
