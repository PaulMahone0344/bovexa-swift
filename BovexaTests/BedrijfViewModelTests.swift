import Testing
import Foundation
@testable import Bovexa

@MainActor
struct BedrijfViewModelTests {
    init() {
        URLProtocolStub.requestHandler = nil
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "bovexa-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func makeViewModel() -> BedrijfViewModel {
        BedrijfViewModel(
            repository: CompanyRepository(client: PBClient(session: URLProtocolStub.makeSession())),
            favoritesStore: FavoritesStore(defaults: makeDefaults())
        )
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

    // MARK: - Ledenlijst (plak 3)

    private static let membersJSON = """
    {
      "items": [
        {"id":"m1","userId":"u1","naam":"Anna","email":"anna@x.nl","avatar":"","role":"admin","status":"active","isOwner":true,"magMaken":true,"magWijzigen":true,"magVerwijderen":true,"magKlantZien":true,"magAgendaAnderenZien":true},
        {"id":"m2","userId":"u2","naam":"Bram","email":"bram@x.nl","avatar":"","role":"member","status":"active","isOwner":false,"magMaken":true,"magWijzigen":false,"magVerwijderen":false,"magKlantZien":true,"magAgendaAnderenZien":true}
      ],
      "seats_max": 3,
      "plan": "free",
      "join_code": "BOVEXA-7F3K",
      "org": {"id":"org1","name":"Bovexa BV","logo":"","ics_token":"","address":"","phone":"","email":"","opening_hours":null,"timezone":"Europe/Amsterdam","default_duration_min":30}
    }
    """

    @Test func loadPopulatesMembersAndRole() async {
        URLProtocolStub.requestHandler = { _ in (200, Self.membersJSON.data(using: .utf8)!) }
        let vm = makeViewModel()
        await vm.load(userId: "u1", token: "tok")
        #expect(vm.members.count == 2)
        #expect(vm.isAdmin("u1"))
        #expect(!vm.isAdmin("u2"))
        #expect(!vm.loading)
    }

    @Test func visibleMembersFiltersBySearchQuery() async {
        URLProtocolStub.requestHandler = { _ in (200, Self.membersJSON.data(using: .utf8)!) }
        let vm = makeViewModel()
        await vm.load(userId: "u1", token: "tok")
        vm.memberQuery = "bram"
        #expect(vm.visibleMembers.map(\.userId) == ["u2"])
    }

    @Test func toggleFavoriteReordersAndPersistsPerUser() async {
        URLProtocolStub.requestHandler = { _ in (200, Self.membersJSON.data(using: .utf8)!) }
        let favoritesStore = FavoritesStore(defaults: makeDefaults())
        let vm = BedrijfViewModel(
            repository: CompanyRepository(client: PBClient(session: URLProtocolStub.makeSession())),
            favoritesStore: favoritesStore
        )
        await vm.load(userId: "u1", token: "tok")

        // Anna komt eerst alfabetisch al vooraan; favoriet maken van Bram zet 'm bovenaan.
        vm.toggleFavorite("u2", currentUserId: "u1")
        #expect(vm.isFavorite("u2"))
        #expect(vm.visibleMembers.first?.userId == "u2")

        // Opnieuw laden (zelfde gebruiker, zelfde opslag) leest de favoriet terug.
        let vm2 = BedrijfViewModel(
            repository: CompanyRepository(client: PBClient(session: URLProtocolStub.makeSession())),
            favoritesStore: favoritesStore
        )
        await vm2.load(userId: "u1", token: "tok")
        #expect(vm2.isFavorite("u2"))
    }
}
