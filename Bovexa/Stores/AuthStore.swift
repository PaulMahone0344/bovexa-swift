import Foundation

enum AuthPhase: Equatable {
    case deciding
    case loggedOut(errorMessage: String?)
    case loggedIn(AgendaUser)
}

/// App-start: token laden → stil authRefresh → dan pas login of tabs tonen.
@MainActor
final class AuthStore: ObservableObject {
    @Published private(set) var phase: AuthPhase = .deciding
    @Published private(set) var token: String?

    private let client: PBClient
    private let tokenStore: TokenStore

    init(client: PBClient = PBClient(), tokenStore: TokenStore = KeychainTokenStore()) {
        self.client = client
        self.tokenStore = tokenStore
    }

    func bootstrap() async {
        guard let savedToken = tokenStore.load() else {
            phase = .loggedOut(errorMessage: nil)
            return
        }
        do {
            let response = try await client.authRefresh(token: savedToken)
            token = response.token
            tokenStore.save(response.token)
            phase = .loggedIn(response.record)
        } catch {
            // Verlopen/ongeldig token: stil terug naar login, geen foutmelding op app-start.
            tokenStore.clear()
            phase = .loggedOut(errorMessage: nil)
        }
    }

    func signIn(email: String, password: String) async {
        do {
            let response = try await client.authWithPassword(email: email, password: password)
            token = response.token
            tokenStore.save(response.token)
            phase = .loggedIn(response.record)
        } catch {
            phase = .loggedOut(errorMessage: Self.dutchMessage(for: error))
        }
    }

    func signOut() {
        tokenStore.clear()
        token = nil
        phase = .loggedOut(errorMessage: nil)
    }

    private static func dutchMessage(for error: Error) -> String {
        guard let pbError = error as? PBError else { return "Er ging iets mis. Probeer het opnieuw." }
        switch pbError {
        case .network:
            return "Geen verbinding. Controleer je internet en probeer opnieuw."
        case .server(let status, _):
            return status == 400 ? "E-mailadres of wachtwoord onjuist." : "Er ging iets mis. Probeer het opnieuw."
        case .decoding:
            return "Er ging iets mis. Probeer het opnieuw."
        }
    }
}
