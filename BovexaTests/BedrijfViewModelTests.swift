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

    // MARK: - Rol, rechten, verwijderen (plak 4, valkuil C)

    private func loadedViewModel() async -> BedrijfViewModel {
        URLProtocolStub.requestHandler = { _ in (200, Self.membersJSON.data(using: .utf8)!) }
        let vm = makeViewModel()
        await vm.load(userId: "u1", token: "tok")
        return vm
    }

    @Test func canBeManagedBlocksAllThreeActionsOnSelfAndOwner() async {
        let vm = await loadedViewModel()
        let owner = vm.members.first { $0.userId == "u1" }!  // isOwner: true
        let me = owner

        URLProtocolStub.requestHandler = { _ in Issue.record("mocht geen request doen"); return (500, Data()) }

        await vm.changeRole(owner, to: .member, actingUserId: "u1", token: "tok")
        await vm.togglePermission(owner, key: .magWijzigen, actingUserId: "u1", token: "tok")
        await vm.removeMember(owner, actingUserId: "u1", token: "tok")

        #expect(vm.members.count == 2) // niets verwijderd
        #expect(vm.members.first { $0.userId == "u1" }?.role == .admin) // rol ongewijzigd
        _ = me
    }

    @Test func failedRoleChangeRollsBack() async {
        let vm = await loadedViewModel()
        let bram = vm.members.first { $0.userId == "u2" }!
        URLProtocolStub.requestHandler = { _ in
            (400, """
            {"message":"Rol wijzigen mislukt."}
            """.data(using: .utf8)!)
        }
        await vm.changeRole(bram, to: .admin, actingUserId: "u1", token: "tok")
        #expect(vm.members.first { $0.userId == "u2" }?.role == .member) // teruggedraaid
        #expect(vm.memberActionErrorMessage == "Rol wijzigen mislukt.")
    }

    @Test func failedPermissionToggleRollsBack() async {
        let vm = await loadedViewModel()
        let bram = vm.members.first { $0.userId == "u2" }!
        URLProtocolStub.requestHandler = { _ in
            (400, """
            {"message":"Rechten wijzigen mislukt."}
            """.data(using: .utf8)!)
        }
        await vm.togglePermission(bram, key: .magWijzigen, actingUserId: "u1", token: "tok")
        #expect(vm.members.first { $0.userId == "u2" }?.magWijzigen == false) // teruggedraaid
        #expect(vm.memberActionErrorMessage == "Rechten wijzigen mislukt.")
    }

    @Test func failedRemoveRollsBack() async {
        let vm = await loadedViewModel()
        let bram = vm.members.first { $0.userId == "u2" }!
        URLProtocolStub.requestHandler = { _ in
            (400, """
            {"message":"Lid verwijderen mislukt."}
            """.data(using: .utf8)!)
        }
        await vm.removeMember(bram, actingUserId: "u1", token: "tok")
        #expect(vm.members.count == 2) // teruggedraaid
        #expect(vm.memberActionErrorMessage == "Lid verwijderen mislukt.")
    }

    @Test func successfulRoleChangeReloadsMembers() async {
        let vm = await loadedViewModel()
        let bram = vm.members.first { $0.userId == "u2" }!
        // Op het pad tellen, niet op de volgorde: load() haalt naast de ledenlijst
        // ook de bedrijfscontacten en de bedrijvenlijst op.
        var memberReloads = 0
        URLProtocolStub.requestHandler = { request in
            let path = request.url?.path ?? ""
            if path.contains("company/member/role") {
                return (200, """
                {"id":"m2","role":"admin"}
                """.data(using: .utf8)!)
            }
            guard path.contains("company/members") else { return (200, Data("{}".utf8)) }
            memberReloads += 1
            // Herlaadactie (valkuil B): server-waarheid wint.
            return (200, """
            {
              "items": [
                {"id":"m1","userId":"u1","naam":"Anna","email":"anna@x.nl","avatar":"","role":"admin","status":"active","isOwner":true,"magMaken":true,"magWijzigen":true,"magVerwijderen":true,"magKlantZien":true,"magAgendaAnderenZien":true},
                {"id":"m2","userId":"u2","naam":"Bram","email":"bram@x.nl","avatar":"","role":"admin","status":"active","isOwner":false,"magMaken":true,"magWijzigen":false,"magVerwijderen":false,"magKlantZien":true,"magAgendaAnderenZien":true}
              ],
              "seats_max": 3, "plan": "free", "join_code": "BOVEXA-7F3K",
              "org": {"id":"org1","name":"Bovexa BV","logo":"","ics_token":"","address":"","phone":"","email":"","opening_hours":null,"timezone":"Europe/Amsterdam","default_duration_min":30}
            }
            """.data(using: .utf8)!)
        }
        await vm.changeRole(bram, to: .admin, actingUserId: "u1", token: "tok")
        #expect(memberReloads == 1) // de rolwissel herlaadt de ledenlijst één keer
        #expect(vm.members.first { $0.userId == "u2" }?.role == .admin)
        #expect(vm.memberActionErrorMessage == nil)
    }

    // MARK: - Tik op de al actieve rol (M11 plak 1d)

    /// `expandedMemberId = nil` stond vóór de guard `role != member.role`: tikken op
    /// de rol die het lid al heeft deed niets behalve de rij dichtklappen, wat als
    /// een fout aanvoelt. De guard hoort eerst.
    @Test func tappingTheAlreadyActiveRoleKeepsTheRowExpanded() async {
        let vm = await loadedViewModel()
        let bram = vm.members.first { $0.userId == "u2" }!  // role: .member
        vm.toggleExpanded(bram.id)
        #expect(vm.expandedMemberId == bram.id)

        URLProtocolStub.requestHandler = { _ in Issue.record("mocht geen request doen"); return (500, Data()) }
        await vm.changeRole(bram, to: .member, actingUserId: "u1", token: "tok")

        #expect(vm.expandedMemberId == bram.id)
        #expect(vm.members.first { $0.userId == "u2" }?.role == .member)
    }

    @Test func changingToAnotherRoleStillCollapsesTheRow() async {
        let vm = await loadedViewModel()
        let bram = vm.members.first { $0.userId == "u2" }!
        vm.toggleExpanded(bram.id)
        URLProtocolStub.requestHandler = { _ in (200, Self.membersJSON.data(using: .utf8)!) }

        await vm.changeRole(bram, to: .admin, actingUserId: "u1", token: "tok")

        #expect(vm.expandedMemberId == nil)
    }

    // MARK: - Plekken-tekst

    @Test func seatsTextShowsCountOfMax() async {
        let vm = await loadedViewModel()
        #expect(vm.seatsText == "2 van 3 accounts")
    }

    /// seats_max 0 betekent onbeperkt (zie TeambeheerViewModel.full) — dan geen
    /// "2 van 0 plekken" op de bedrijfskaart.
    @Test func seatsTextHiddenWhenUnlimited() async {
        URLProtocolStub.requestHandler = { _ in
            (200, Self.membersJSON.replacingOccurrences(of: "\"seats_max\": 3", with: "\"seats_max\": 0").data(using: .utf8)!)
        }
        let vm = makeViewModel()
        await vm.load(userId: "u1", token: "tok")
        #expect(vm.seatsMax == 0)
        #expect(vm.seatsText == nil)
    }

    @Test func seatsTextNilBeforeLoad() {
        let vm = makeViewModel()
        #expect(vm.seatsText == nil)
    }
}
