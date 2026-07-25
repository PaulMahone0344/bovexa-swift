import Testing
import Foundation
@testable import Bovexa

@MainActor
struct BedrijfViewModelTests {
    init() {
        URLProtocolStub.requestHandler = nil
    }

    private func makeViewModel() -> BedrijfViewModel {
        BedrijfViewModel(repository: CompanyRepository(client: PBClient(session: URLProtocolStub.makeSession())))
    }

    // MARK: - Aanmaken

    @Test func emptyNameBlocksCreate() async {
        let vm = makeViewModel()
        vm.nameDraft = " "
        let success = await vm.createCompany(token: "tok")
        #expect(!success)
        #expect(vm.errorMessage == "Vul een bedrijfsnaam in (min. 2 tekens).")
        #expect(!vm.justJoined)
    }

    @Test func tooShortNameBlocksCreate() async {
        let vm = makeViewModel()
        vm.nameDraft = "B"
        let success = await vm.createCompany(token: "tok")
        #expect(!success)
        #expect(vm.errorMessage == "Vul een bedrijfsnaam in (min. 2 tekens).")
    }

    @Test func createSuccessSetsJustJoined() async {
        URLProtocolStub.requestHandler = { _ in
            (200, """
            {"id":"org1","name":"Bovexa BV","join_code":"BOVEXA-7F3K","plan":"free","seats_max":3,"role":"admin"}
            """.data(using: .utf8)!)
        }
        let vm = makeViewModel()
        vm.nameDraft = "Bovexa BV"
        let success = await vm.createCompany(token: "tok")
        #expect(success)
        #expect(vm.justJoined)
        #expect(vm.errorMessage == nil)
        #expect(!vm.busy)
    }

    // MARK: - Toetreden

    @Test func emptyCodeBlocksJoin() async {
        let vm = makeViewModel()
        vm.codeDraft = "  "
        let success = await vm.joinCompany(token: "tok")
        #expect(!success)
        #expect(vm.errorMessage == "Vul een bedrijfscode in.")
    }

    @Test func seatsFullShowsOwnText() async {
        URLProtocolStub.requestHandler = { _ in
            (400, """
            {"message":"Bedrijf zit vol."}
            """.data(using: .utf8)!)
        }
        let vm = makeViewModel()
        vm.codeDraft = "BOVEXA-7F3K"
        let success = await vm.joinCompany(token: "tok")
        #expect(!success)
        #expect(vm.errorMessage == "Bedrijf zit vol.")
        #expect(!vm.justJoined)
    }

    @Test func rateLimitShowsOwnText() async {
        URLProtocolStub.requestHandler = { _ in
            (429, """
            {"message":"Te veel pogingen. Probeer over een minuut opnieuw."}
            """.data(using: .utf8)!)
        }
        let vm = makeViewModel()
        vm.codeDraft = "BOVEXA-7F3K"
        let success = await vm.joinCompany(token: "tok")
        #expect(!success)
        #expect(vm.errorMessage == "Te veel pogingen. Probeer over een minuut opnieuw.")
    }

    @Test func joinSuccessSetsJustJoined() async {
        URLProtocolStub.requestHandler = { _ in
            (200, """
            {"id":"org1","name":"Bovexa BV","join_code":"BOVEXA-7F3K","plan":"free","seats_max":3,"role":"member"}
            """.data(using: .utf8)!)
        }
        let vm = makeViewModel()
        vm.codeDraft = "BOVEXA-7F3K"
        let success = await vm.joinCompany(token: "tok")
        #expect(success)
        #expect(vm.justJoined)
    }

    // MARK: - Modus wisselen

    @Test func openModeClearsPreviousError() {
        let vm = makeViewModel()
        vm.errorMessage = "iets"
        vm.openMode(.name)
        #expect(vm.emptyMode == .name)
        #expect(vm.errorMessage == nil)
    }
}
