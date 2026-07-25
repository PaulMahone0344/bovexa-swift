import Testing
import Foundation
@testable import Bovexa

@MainActor
struct YearOverviewViewModelTests {
    init() {
        URLProtocolStub.requestHandler = nil
    }

    private func makeViewModel(now: @escaping () -> Date = { PBDate.parse("2026-08-03 09:00:00.000Z")! }) -> YearOverviewViewModel {
        YearOverviewViewModel(repository: EventRepository(client: PBClient(session: URLProtocolStub.makeSession())), now: now)
    }

    @Test func initDefaultsToCurrentYear() {
        let vm = makeViewModel()
        #expect(vm.year == 2026)
    }

    @Test func yearNavigationShiftsByOne() {
        let vm = makeViewModel()
        vm.goToPreviousYear()
        #expect(vm.year == 2025)
        vm.goToNextYear()
        #expect(vm.year == 2026)
    }

    @Test func loadPopulatesDayCountsPerMonth() async {
        URLProtocolStub.requestHandler = { _ in
            let json = """
            {"items":[
              {"id":"a","owner":"u1","title":"T","start":"2026-08-03 09:00:00.000Z","all_day":false},
              {"id":"b","owner":"u1","title":"T","start":"2026-08-10 09:00:00.000Z","all_day":false},
              {"id":"c","owner":"u1","title":"T","start":"2026-09-01 09:00:00.000Z","all_day":false}
            ],"page":1,"perPage":200,"totalItems":3,"totalPages":1}
            """.data(using: .utf8)!
            return (200, json)
        }
        let vm = makeViewModel()
        await vm.load(userId: "u1", orgId: nil, token: "tok")
        #expect(vm.dayCount(forMonth: 7) == 2) // augustus, 0-based
        #expect(vm.dayCount(forMonth: 8) == 1) // september
        #expect(vm.hasEvents(month: 7, day: 3))
        #expect(!vm.hasEvents(month: 7, day: 4))
        #expect(vm.totalDaysPlannedThisYear == 3)
    }

    @Test func networkFailureLeavesEmptyStateInsteadOfCrashing() async {
        URLProtocolStub.requestHandler = nil
        let vm = makeViewModel()
        await vm.load(userId: "u1", orgId: nil, token: "tok")
        #expect(vm.dayCount(forMonth: 7) == 0)
    }
}
