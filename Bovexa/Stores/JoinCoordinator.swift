import Foundation

/// Houdt de staat bij van een inkomende join-deeplink over de login-grens heen
/// (valkuil G: drie uitkomsten — niet ingelogd, al lid, of toetreden). RootRouterView
/// vangt `.onOpenURL` op en roept hier in; RootTabView reageert op `outcome`.
@MainActor
final class JoinCoordinator: ObservableObject {
    enum Outcome: Equatable {
        case idle
        case joining
        case alreadyMember
        case joined
        case failed(String)
    }

    /// Code van een deeplink die binnenkwam terwijl de gebruiker nog niet was
    /// ingelogd — na een geslaagde login alsnog verwerken.
    @Published var pendingCode: String?
    @Published private(set) var outcome: Outcome = .idle

    private let repository: CompanyRepository

    init(repository: CompanyRepository = CompanyRepository()) {
        self.repository = repository
    }

    func join(code: String, alreadyHasCompany: Bool, token: String) async {
        if alreadyHasCompany {
            outcome = .alreadyMember
            return
        }
        outcome = .joining
        do {
            _ = try await repository.joinCompany(code: code, token: token)
            outcome = .joined
        } catch {
            outcome = .failed((error as? CompanyError)?.message ?? "Toetreden mislukt.")
        }
    }

    func reset() {
        outcome = .idle
        pendingCode = nil
    }
}
