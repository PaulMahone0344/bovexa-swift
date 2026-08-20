import Testing
import Foundation
@testable import Bovexa

/// LegendeViewModel — rol laden (verwijderen alleen admin, valkuil G), hernoemen/
/// kleur wijzigen/toevoegen/verwijderen via LabelRepository + LabelStore.
@MainActor
struct LegendeViewModelTests {
    init() {
        URLProtocolStub.requestHandler = nil
    }

    private func label(_ id: String, naam: String = "VSB", kleur: String = "#E08A3C", volgorde: Int = 0) -> AgendaLabel {
        AgendaLabel(id: id, org: "org1", naam: naam, kleur: kleur, volgorde: volgorde)
    }

    private func makeViewModel(labelStore: LabelStore = LabelStore()) -> LegendeViewModel {
        let session = URLProtocolStub.makeSession()
        return LegendeViewModel(
            userId: "me", org: "org1", token: "tok", labelStore: labelStore,
            labelRepository: LabelRepository(client: PBClient(session: session)),
            companyRepository: CompanyRepository(client: PBClient(session: session))
        )
    }

    private func routedHandler(role: String) -> (URLRequest) -> (Int, Data) {
        { request in
            if request.url!.path.contains("company/members") {
                let json = """
                {"items":[{"id":"m1","userId":"me","naam":"Ik","email":"ik@bovexa.nl","avatar":"","role":"\(role)","status":"active","isOwner":false,"magMaken":true,"magWijzigen":true,"magVerwijderen":true,"magKlantZien":true,"magAgendaAnderenZien":true}],
                 "seats_max":3,"plan":"free","join_code":"ABC123","org":null}
                """
                return (200, json.data(using: .utf8)!)
            }
            return (404, Data())
        }
    }

    // MARK: - isAdmin (valkuil G)

    @Test func loadRoleSetsIsAdminTrueForAdmin() async {
        URLProtocolStub.requestHandler = routedHandler(role: "admin")
        let vm = makeViewModel()
        await vm.loadRole()
        #expect(vm.isAdmin == true)
    }

    @Test func loadRoleSetsIsAdminFalseForMember() async {
        URLProtocolStub.requestHandler = routedHandler(role: "member")
        let vm = makeViewModel()
        await vm.loadRole()
        #expect(vm.isAdmin == false)
    }

    // MARK: - rename

    @Test func renameUpdatesLabelStore() async {
        let store = LabelStore()
        store.prime(labels: [label("l1", naam: "Oud")])
        URLProtocolStub.requestHandler = { _ in
            (200, Data("""
            {"id":"l1","org":"org1","naam":"Nieuw","kleur":"#E08A3C","volgorde":0}
            """.utf8))
        }
        let vm = makeViewModel(labelStore: store)
        await vm.rename(label("l1", naam: "Oud"), to: "Nieuw")
        #expect(store.label(for: "l1")?.naam == "Nieuw")
    }

    // MARK: - updateColor

    @Test func updateColorUpdatesLabelStore() async {
        let store = LabelStore()
        store.prime(labels: [label("l1")])
        URLProtocolStub.requestHandler = { _ in
            (200, Data("""
            {"id":"l1","org":"org1","naam":"VSB","kleur":"#3E87D6","volgorde":0}
            """.utf8))
        }
        let vm = makeViewModel(labelStore: store)
        await vm.updateColor(label("l1"), to: "#3E87D6")
        #expect(store.label(for: "l1")?.kleur == "#3E87D6")
    }

    // MARK: - create

    @Test func createAddsLabelToStore() async {
        let store = LabelStore()
        URLProtocolStub.requestHandler = { _ in
            (200, Data("""
            {"id":"l2","org":"org1","naam":"Kimberley","kleur":"#D45AA4","volgorde":0}
            """.utf8))
        }
        let vm = makeViewModel(labelStore: store)
        let created = await vm.create(naam: "Kimberley", kleur: "#D45AA4")
        #expect(created)
        #expect(store.label(for: "l2")?.naam == "Kimberley")
    }

    /// De view wiste de naam en sloot het formulier ook als het aanmaken faalde:
    /// je zag "Mislukt" en was je invoer kwijt. Daarom geeft create nu terug of
    /// het gelukt is.
    @Test func createReturnsFalseWhenTheServerRefuses() async {
        let store = LabelStore()
        URLProtocolStub.requestHandler = { _ in (400, Data("{}".utf8)) }
        let vm = makeViewModel(labelStore: store)

        let created = await vm.create(naam: "Kimberley", kleur: "#D45AA4")

        #expect(!created)
        #expect(vm.actionFailedAlert)
        #expect(store.orderedLabels.isEmpty)
    }

    @Test func createReturnsFalseOnAnEmptyName() async {
        let vm = makeViewModel()
        #expect(await vm.create(naam: "   ", kleur: "#D45AA4") == false)
    }

    /// Zonder busy-guard maakte een dubbele tik twee labels met dezelfde naam aan.
    @Test func createIsBlockedWhileAnotherCreateIsRunning() async {
        let store = LabelStore()
        URLProtocolStub.requestHandler = { _ in
            (200, Data("""
            {"id":"l2","org":"org1","naam":"Kimberley","kleur":"#D45AA4","volgorde":0}
            """.utf8))
        }
        let vm = makeViewModel(labelStore: store)

        async let first = vm.create(naam: "Kimberley", kleur: "#D45AA4")
        async let second = vm.create(naam: "Kimberley", kleur: "#D45AA4")
        let results = await [first, second]

        // Precies één van de twee mag doorgaan.
        #expect(results.filter { $0 }.count == 1)
        #expect(store.orderedLabels.count == 1)
        #expect(!vm.busy)
    }

    // MARK: - delete (valkuil G: alleen admin)

    @Test func deleteAsAdminRemovesFromStore() async {
        let store = LabelStore()
        store.prime(labels: [label("l1")])
        let vm = makeViewModel(labelStore: store)
        URLProtocolStub.requestHandler = routedHandler(role: "admin")
        await vm.loadRole()

        URLProtocolStub.requestHandler = { request in
            #expect(request.httpMethod == "DELETE")
            return (204, Data())
        }
        await vm.delete(label("l1"))
        #expect(store.label(for: "l1") == nil)
    }

    @Test func deleteAsNonAdminDoesNothing() async {
        let store = LabelStore()
        store.prime(labels: [label("l1")])
        let vm = makeViewModel(labelStore: store)
        URLProtocolStub.requestHandler = routedHandler(role: "member")
        await vm.loadRole()

        URLProtocolStub.requestHandler = { request in
            Issue.record("mocht geen verwijder-verzoek doen zonder adminrol")
            return (500, Data())
        }
        await vm.delete(label("l1"))
        #expect(store.label(for: "l1") != nil)
    }
}
