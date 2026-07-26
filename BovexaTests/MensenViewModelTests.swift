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
