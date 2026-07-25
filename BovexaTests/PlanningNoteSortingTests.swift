import Testing
import Foundation
@testable import Bovexa

struct PlanningNoteSortingTests {
    private func note(id: String, done: Bool, daysAgo: Double, archived: Bool = false) -> PlanningNote {
        PlanningNote(
            id: id, title: id, body: "", done: done,
            createdAt: Date(timeIntervalSince1970: 1_000_000 - daysAgo * 86_400),
            updatedAt: Date(timeIntervalSince1970: 1_000_000 - daysAgo * 86_400),
            archived: archived
        )
    }

    @Test func openNotesSortBeforeDoneNotes() {
        let done = note(id: "done", done: true, daysAgo: 0)
        let open = note(id: "open", done: false, daysAgo: 5)
        let sorted = PlanningNoteSorting.sort([done, open])
        #expect(sorted.map(\.id) == ["open", "done"])
    }

    @Test func withinSameDoneStatusNewestFirst() {
        let older = note(id: "older", done: false, daysAgo: 5)
        let newer = note(id: "newer", done: false, daysAgo: 1)
        let sorted = PlanningNoteSorting.sort([older, newer])
        #expect(sorted.map(\.id) == ["newer", "older"])
    }

    @Test func archivedStatusDoesNotAffectOrder() {
        let openNewer = note(id: "open-newer", done: false, daysAgo: 1)
        let archivedOlder = note(id: "archived-older", done: false, daysAgo: 5, archived: true)
        let sorted = PlanningNoteSorting.sort([archivedOlder, openNewer])
        #expect(sorted.map(\.id) == ["open-newer", "archived-older"])
    }

    @Test func mixedDoneAndDatesSortsDoneGroupSeparately() {
        let a = note(id: "a-open-old", done: false, daysAgo: 10)
        let b = note(id: "b-done-new", done: true, daysAgo: 1)
        let c = note(id: "c-open-new", done: false, daysAgo: 1)
        let d = note(id: "d-done-old", done: true, daysAgo: 10)
        let sorted = PlanningNoteSorting.sort([a, b, c, d])
        #expect(sorted.map(\.id) == ["c-open-new", "a-open-old", "b-done-new", "d-done-old"])
    }
}
