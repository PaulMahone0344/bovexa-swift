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

    private let repository: CompanyRepository

    init(repository: CompanyRepository = CompanyRepository()) {
        self.repository = repository
    }

    var hasLoadedCompany: Bool { membersResponse != nil }
    var members: [CompanyMember] { membersResponse?.items ?? [] }
    var org: CompanyOrgProfile? { membersResponse?.org }
    var seatsMax: Int? { membersResponse?.seatsMax }
    var joinCode: String? { membersResponse?.joinCode }

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

    func load(token: String) async {
        if membersResponse == nil { loading = true }
        do {
            membersResponse = try await repository.listMembers(token: token)
        } catch {
            membersResponse = nil
        }
        loading = false
        refreshing = false
    }

    func refresh(token: String) async {
        refreshing = true
        await load(token: token)
    }

    private static func errorText(_ error: Error, fallback: String) -> String {
        (error as? CompanyError)?.message ?? fallback
    }
}
