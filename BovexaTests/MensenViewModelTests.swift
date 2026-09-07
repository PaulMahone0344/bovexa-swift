import Testing
import Foundation
@testable import Bovexa

@MainActor
struct MensenViewModelTests {
    init() {
        URLProtocolStub.requestHandler = nil
    }

    private func makeViewModel() -> MensenViewModel {
        let session = URLProtocolStub.makeSession()
        return MensenViewModel(
            contactRepository: ContactRepository(client: PBClient(session: session)),
            companyRepository: CompanyRepository(client: PBClient(session: session))
        )
    }

    // MARK: - load

    @Test func loadPopulatesContactsAndMembers() async {
        URLProtocolStub.requestHandler = { request in
            if request.url!.absoluteString.contains("agenda_contacten") {
                let json = """
                {"items":[{"id":"c1","eigenaar":"u1","naam":"Karim","telefoon":"","notitie":""}],
                 "page":1,"perPage":200,"totalItems":1,"totalPages":1}
                """.data(using: .utf8)!
                return (200, json)
            }
            let json = """
            {"items":[{"id":"m1","userId":"u2","naam":"Yassine","email":"yassine@bovexa.nl","avatar":"","role":"member","status":"active","isOwner":false,"magMaken":true,"magWijzigen":true,"magVerwijderen":false,"magKlantZien":true,"magAgendaAnderenZien":true}],
             "seats_max":5,"plan":"free","join_code":"X",
             "org":{"id":"org1","name":"Bovexa.nl","logo":"","ics_token":"","address":"","phone":"","email":"","timezone":"Europe/Amsterdam","default_duration_min":60}}
            """.data(using: .utf8)!
            return (200, json)
        }
        let vm = makeViewModel()
        await vm.load(userId: "u1", token: "tok")
        #expect(vm.contacts.map(\.id) == ["c1"])
        #expect(vm.members.map(\.id) == ["m1"])
        #expect(vm.orgName == "Bovexa.nl")
    }

    /// Sinds het serverveld `org` komen de bedrijfscontacten van collega's mee in
    /// dezelfde lijst. Onder "PRIVÉ" hoort daar niets van te staan.
    @Test func privelijstToontAlleenEigenContactenZonderBedrijf() async {
        URLProtocolStub.requestHandler = { request in
            if request.url!.absoluteString.contains("agenda_contacten") {
                let json = """
                {"items":[
                  {"id":"c1","eigenaar":"u1","naam":"Karim","telefoon":"","notitie":"","org":""},
                  {"id":"c2","eigenaar":"u1","naam":"Loubna","telefoon":"","notitie":"","org":"org1"},
                  {"id":"c3","eigenaar":"u2","naam":"Sanae","telefoon":"","notitie":"","org":"org1"}
                 ],"page":1,"perPage":200,"totalItems":3,"totalPages":1}
                """.data(using: .utf8)!
                return (200, json)
            }
            let json = """
            {"items":[],"seats_max":5,"plan":"free","join_code":"X",
             "org":{"id":"org1","name":"Bovexa.nl","logo":"","ics_token":"","address":"","phone":"","email":"","timezone":"Europe/Amsterdam","default_duration_min":60}}
            """.data(using: .utf8)!
            return (200, json)
        }
        let vm = makeViewModel()
        await vm.load(userId: "u1", defaultOrg: "org1", token: "tok")
        #expect(vm.contacts.map(\.id) == ["c1", "c2", "c3"])
        #expect(vm.visiblePrivateContacts.map(\.id) == ["c1"])
    }

    /// Wissen mag alleen de eigenaar (deleteRule); bewerken mag iedereen die het
    /// contact ziet.
    @Test func magVerwijderenAlleenBijEigenContact() async {
        URLProtocolStub.requestHandler = { request in
            if request.url!.absoluteString.contains("agenda_contacten") {
                let json = """
                {"items":[
                  {"id":"c1","eigenaar":"u1","naam":"Karim","telefoon":"","notitie":"","org":""},
                  {"id":"c3","eigenaar":"u2","naam":"Sanae","telefoon":"","notitie":"","org":"org1"}
                 ],"page":1,"perPage":200,"totalItems":2,"totalPages":1}
                """.data(using: .utf8)!
                return (200, json)
            }
            let json = """
            {"items":[],"seats_max":5,"plan":"free","join_code":"X","org":null}
            """.data(using: .utf8)!
            return (200, json)
        }
        let vm = makeViewModel()
        await vm.load(userId: "u1", defaultOrg: "org1", token: "tok")
        let eigen = vm.contacts.first { $0.id == "c1" }!
        let vanCollega = vm.contacts.first { $0.id == "c3" }!
        #expect(vm.magVerwijderen(eigen))
        #expect(!vm.magVerwijderen(vanCollega))
    }

    // MARK: - addContact

    @Test func addContactWithEmptyNaamBlocksSave() async {
        let vm = makeViewModel()
        let success = await vm.addContact(userId: "u1", naam: "  ", telefoon: "", notitie: "", token: "tok")
        #expect(!success)
        #expect(vm.errorMessage == "Vul een naam in.")
    }

    @Test func addContactAppearsImmediatelyInContacts() async {
        URLProtocolStub.requestHandler = { request in
            #expect(request.httpMethod == "POST")
            let json = """
            {"id":"c2","eigenaar":"u1","naam":"Sanae","telefoon":"","notitie":""}
            """.data(using: .utf8)!
            return (200, json)
        }
        let vm = makeViewModel()
        let success = await vm.addContact(userId: "u1", naam: "Sanae", telefoon: "", notitie: "", token: "tok")
        #expect(success)
        #expect(vm.contacts.map(\.naam) == ["Sanae"])
    }

    // MARK: - deleteContact

    @Test func deleteContactRemovesItFromContacts() async {
        URLProtocolStub.requestHandler = { _ in (204, Data()) }
        let vm = makeViewModel()
        _ = await vm.addContact(userId: "u1", naam: "Tijdelijk", telefoon: "", notitie: "", token: "tok")
        URLProtocolStub.requestHandler = { request in
            #expect(request.httpMethod == "DELETE")
            return (204, Data())
        }
        await vm.deleteContact(id: vm.contacts.first?.id ?? "", token: "tok")
        #expect(vm.contacts.isEmpty)
    }
}
