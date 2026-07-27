import Testing
import Foundation
@testable import Bovexa

struct TeamTaskGroupingTests {
    private func task(
        _ id: String, status: TaskStatus = .open, created: TimeInterval = 0, completedAt: TimeInterval? = nil
    ) -> AgendaTask {
        AgendaTask(
            id: id, owner: "u1", org: "org1", title: id, notes: nil, status: status,
            visibility: .company, viewers: [], created: Date(timeIntervalSince1970: created),
            updated: Date(timeIntervalSince1970: created),
            completedAt: completedAt.map { Date(timeIntervalSince1970: $0) }
        )
    }

    @Test func openTasksStayOnTopInTheOrderTheyCameIn() {
        let result = TeamTaskGrouping.split([
            task("a", created: 100),
            task("b", status: .klaar, created: 200, completedAt: 300),
            task("c", created: 50),
        ])

        #expect(result.open.map(\.id) == ["a", "c"])
        #expect(result.done.map(\.id) == ["b"])
    }

    /// Laatst afgevinkt bovenaan: wat je net hebt gedaan wil je terugzien zonder
    /// door de hele stapel van vorige week te scrollen.
    @Test func doneTasksAreSortedByMostRecentlyCompleted() {
        let result = TeamTaskGrouping.split([
            task("oud", status: .klaar, created: 10, completedAt: 100),
            task("nieuw", status: .klaar, created: 20, completedAt: 900),
            task("midden", status: .klaar, created: 30, completedAt: 500),
        ])

        #expect(result.done.map(\.id) == ["nieuw", "midden", "oud"])
    }

    /// Taken die klaar waren vóórdat completed_at bestond hebben geen tijdstip; die
    /// horen onderaan en mogen de sortering niet laten omvallen.
    @Test func doneTasksWithoutATimestampSinkToTheBottom() {
        let result = TeamTaskGrouping.split([
            task("zonder", status: .klaar, created: 10),
            task("met", status: .klaar, created: 20, completedAt: 500),
        ])

        #expect(result.done.map(\.id) == ["met", "zonder"])
    }

    @Test func everythingOpenGivesAnEmptyDoneList() {
        let result = TeamTaskGrouping.split([task("a"), task("b")])

        #expect(result.open.count == 2)
        #expect(result.done.isEmpty)
    }
}
