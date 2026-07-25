import Foundation

/// Viewmodel voor de Bedrijf-tab: zonder bedrijf (starten/toetreden) én met bedrijf
/// (bedrijfskaart, ledenlijst, rol/rechten-beheer). Eén viewmodel voor beide staten,
/// zoals de RN Bedrijf()-component ook één scherm is met een EmptyOrg-substaat.
@MainActor
final class BedrijfViewModel: ObservableObject {
    enum EmptyMode {
        case choice
        case name
        case code
    }

    @Published var emptyMode: EmptyMode = .choice
    @Published var nameDraft = ""
    @Published var codeDraft = ""
    @Published private(set) var busy = false
    @Published var errorMessage: String?

    /// Optimistisch gezet zodra create/join lukt — de view schakelt hierop meteen
    /// door naar de bedrijfsstaat, vooruitlopend op AuthStore.refreshCurrentUser().
    @Published private(set) var justJoined = false

    @Published private(set) var loading = false
    @Published private(set) var refreshing = false
    @Published private(set) var membersResponse: CompanyMembersResponse?

    @Published private(set) var favorites: [String] = []
    @Published var memberQuery = ""

    let memberColors = MemberColors()

    private let repository: CompanyRepository
    private let favoritesStore: FavoritesStore

    init(repository: CompanyRepository = CompanyRepository(), favoritesStore: FavoritesStore = FavoritesStore()) {
        self.repository = repository
        self.favoritesStore = favoritesStore
    }

    var hasLoadedCompany: Bool { membersResponse != nil }
    var members: [CompanyMember] { membersResponse?.items ?? [] }
    var org: CompanyOrgProfile? { membersResponse?.org }
    var seatsMax: Int? { membersResponse?.seatsMax }
    var joinCode: String? { membersResponse?.joinCode }

    /// Favorieten bovenaan, daarna alfabetisch; zoekbalk verschijnt vanaf 6 leden
    /// (view beslist, dit is puur de gefilterde/gesorteerde data).
    var visibleMembers: [CompanyMember] {
        CompanyMemberSearchHelpers.sortMembers(CompanyMemberSearchHelpers.filterMembers(members, query: memberQuery), favorites: favorites)
    }

    func isFavorite(_ userId: String) -> Bool { favorites.contains(userId) }

    func toggleFavorite(_ memberUserId: String, currentUserId: String) {
        favorites = CompanyMemberSearchHelpers.toggleFavorite(memberUserId, in: favorites)
        favoritesStore.save(favorites, userId: currentUserId)
    }

    func role(for userId: String) -> CompanyRole? {
        members.first { $0.userId == userId }?.role
    }

    func isAdmin(_ userId: String) -> Bool {
        role(for: userId) == .admin
    }

    var canCreate: Bool { !nameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !busy }
    var canJoin: Bool { !codeDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !busy }

    func openMode(_ mode: EmptyMode) {
        errorMessage = nil
        emptyMode = mode
    }

    @discardableResult
    func createCompany(token: String) async -> Bool {
        let trimmed = nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            errorMessage = "Vul een bedrijfsnaam in (min. 2 tekens)."
            return false
        }
        errorMessage = nil
        busy = true
        defer { busy = false }
        do {
            _ = try await repository.createCompany(name: trimmed, token: token)
            justJoined = true
            return true
        } catch {
            errorMessage = Self.errorText(error, fallback: "Bedrijf aanmaken mislukt.")
            return false
        }
    }

    @discardableResult
    func joinCompany(token: String) async -> Bool {
        let trimmed = codeDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Vul een bedrijfscode in."
            return false
        }
        errorMessage = nil
        busy = true
        defer { busy = false }
        do {
            _ = try await repository.joinCompany(code: trimmed, token: token)
            justJoined = true
            return true
        } catch {
            errorMessage = Self.errorText(error, fallback: "Toetreden mislukt.")
            return false
        }
    }

    func load(userId: String, token: String) async {
        if membersResponse == nil { loading = true }
        favorites = favoritesStore.load(userId: userId)
        do {
            let response = try await repository.listMembers(token: token)
            membersResponse = response
            memberColors.prime(
                members: response.items.map { Member(id: $0.id, userId: $0.userId, naam: $0.naam, email: $0.email, avatar: $0.avatar) },
                org: response.org.map { CompanyOrgInfo(id: $0.id, name: $0.name, logo: $0.logo) }
            )
        } catch {
            membersResponse = nil
        }
        loading = false
        refreshing = false
    }

    func refresh(userId: String, token: String) async {
        refreshing = true
        await load(userId: userId, token: token)
    }

    private static func errorText(_ error: Error, fallback: String) -> String {
        (error as? CompanyError)?.message ?? fallback
    }
}
