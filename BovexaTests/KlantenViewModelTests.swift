import Testing
import Foundation
@testable import Bovexa

@MainActor
struct KlantenViewModelTests {
    init() {
        URLProtocolStub.requestHandler = nil
    }

    private func makeViewModel(userId: String = "me", orgId: String? = "org1") -> KlantenViewModel {
        let session = URLProtocolStub.makeSession()
        return KlantenViewModel(
            userId: userId, orgId: orgId, token: "tok",
            repository: EventRepository(client: PBClient(session: session)),
            labelRepository: LabelRepository(client: PBClient(session: session))
        )
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

    // MARK: - Leden en labels primen (M11 plak 3e)

    /// Het afspraak-detail vanuit Klanten kreeg verse, nooit geprimede stores mee:
    /// een collega heette "collega", labelkleuren ontbraken en de editor kon
    /// niemand toewijzen.
    @Test func loadPrimesMemberColorsAndLabels() async {
        URLProtocolStub.requestHandler = { request in
            let path = request.url!.path
            if path.contains("company/members") {
                return (200, Data("""
                {"items":[{"id":"m1","userId":"u2","naam":"Daan","email":"daan@bovexa.nl","avatar":""}],
                 "org":{"id":"org1","name":"Bovexa","logo":""}}
                """.utf8))
            }
            if path.contains("agenda_labels") {
                return (200, Data("""
                {"items":[{"id":"l1","org":"org1","naam":"VSB","kleur":"#FF9500","volgorde":0}],
                 "page":1,"perPage":200,"totalItems":1,"totalPages":1}
                """.utf8))
            }
            return (200, Data("""
            {"items":[{"id":"a","owner":"me","title":"Knippen","start":"2026-07-24 09:00:00.000Z","all_day":false,"klant_naam":"Jansen"}],
             "page":1,"perPage":200,"totalItems":1,"totalPages":1}
            """.utf8))
        }
        let vm = makeViewModel()
        await vm.load()

        #expect(vm.memberColors.firstName(for: "u2") == "Daan")
        #expect(vm.labelStore.label(for: "l1")?.naam == "VSB")
    }

    @Test func loadWithoutOrgSkipsTheLabelFetch() async {
        URLProtocolStub.requestHandler = { request in
            if request.url!.path.contains("agenda_labels") {
                Issue.record("zonder bedrijf horen er geen labels opgehaald te worden")
            }
            return (200, Data("""
            {"items":[],"page":1,"perPage":200,"totalItems":0,"totalPages":0}
            """.utf8))
        }
        let vm = makeViewModel(orgId: nil)
        await vm.load()
        #expect(vm.labelStore.orderedLabels.isEmpty)
    }
}
