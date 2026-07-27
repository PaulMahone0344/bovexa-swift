import Testing
import Foundation
@testable import Bovexa

struct TaskPermissionsTests {
    private func task(owner: String, visibility: TaskVisibility?) -> AgendaTask {
        AgendaTask(
            id: "t1", owner: owner, org: "org1", title: "Banden controleren", notes: nil,
            status: .open, visibility: visibility, viewers: [], created: Date(), updated: Date()
        )
    }

    @Test func youMayAlwaysTickOffYourOwnTask() {
        #expect(TaskPermissions.canToggle(task(owner: "me", visibility: .private), userId: "me"))
    }

    /// Een gedeelde taak is teamwerk: wie hem doet, vinkt hem af.
    @Test func aColleagueMayTickOffACompanyTask() {
        #expect(TaskPermissions.canToggle(task(owner: "u2", visibility: .company), userId: "me"))
    }

    /// Een privétaak van een collega hoor je niet te zien, laat staan af te vinken —
    /// staat hij er door een fout tóch, dan blijft het vinkje dicht.
    @Test func aColleaguesPrivateTaskStaysUntouchable() {
        #expect(!TaskPermissions.canToggle(task(owner: "u2", visibility: .private), userId: "me"))
    }

    /// Wissen blijft bij de eigenaar: niemand gooit het werk van een ander weg.
    @Test func onlyTheOwnerMayDelete() {
        #expect(TaskPermissions.canDelete(task(owner: "me", visibility: .company), userId: "me"))
        #expect(!TaskPermissions.canDelete(task(owner: "u2", visibility: .company), userId: "me"))
    }
}
