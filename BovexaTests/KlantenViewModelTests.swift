import Testing
import Foundation
@testable import Bovexa

@MainActor
struct KlantenViewModelTests {
    init() {
        URLProtocolStub.requestHandler = nil
    }

    private func makeViewModel(userId: String = "me", orgId: String? = "org1") -> KlantenViewModel {
        KlantenViewModel(userId: userId, orgId: orgId, token: "tok", repository: EventRepository(client: PBClient(session: URLProtocolStub.makeSession())))
    }

    @Test func loadGroupsEventsByKlant() async {
        URLProtocolStub.requestHandler = { _ in (200, """
        {"items":[
          {"id":"a","owner":"me","title":"Knippen","start":"2026-07-24 09:00:00.000Z","all_day":false,"klant_naam":"Jansen"},
          {"id":"b","owner":"me","title":"Kleuren","start":"2026-07-25 09:00:00.000Z","all_day":false,"klant_naam":"Jansen"},
          {"id":"c","owner":"me","title":"Zonder klant","start":"2026-07-26 09:00:00.000Z","all_day":false}
        ],"page":1,"perPage":200,"totalItems":3,"totalPages":1}
        """.data(using: .utf8)!) }
        let vm = makeViewModel()
        #expect(vm.loading)
        await vm.load()
        #expect(!vm.loading)
        #expect(vm.groups.map(\.naam) == ["Jansen"])
        #expect(vm.groups[0].events.count == 2)
    }

    @Test func networkFailureLeavesEmptyGroupsInsteadOfCrashing() async {
        URLProtocolStub.requestHandler = nil
        let vm = makeViewModel()
        await vm.load()
        #expect(vm.groups.isEmpty)
        #expect(!vm.loading)
    }
}
