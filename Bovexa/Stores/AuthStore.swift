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
    /// Aan direct na een geslaagde registratie — RootRouterView toont dan de
    /// onboardingstap (bedrijf starten/code invoeren/overslaan, valkuil A) in
    /// plaats van meteen de tabs. Uit via `finishOnboarding()`.
    @Published private(set) var justRegistered = false

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

    /// Ververst het account na een server-mutatie die buiten AuthStore om gebeurde
    /// (bv. company/create of company/join zet `default_org`). De mutatie is dan al
    /// gelukt — een netwerkhikje hierna mag geen foutmelding tonen, dit is puur
    /// state-sync (zelfde principe als refresh() in de RN-auth-context).
    func refreshCurrentUser() async {
        guard let token else { return }
        do {
            let response = try await client.authRefresh(token: token)
            self.token = response.token
            tokenStore.save(response.token)
            phase = .loggedIn(response.record)
        } catch {
            // Stil negeren — zie doc-comment hierboven.
        }
    }

    func signOut() {
        tokenStore.clear()
        token = nil
        phase = .loggedOut(errorMessage: nil)
    }

    /// Registratie (valkuil A): create op agenda_users, dan direct inloggen —
    /// zelfde volgorde als AuthProvider.signUp in de RN-app.
    func signUp(email: String, password: String, naam: String) async {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            _ = try await client.register(email: trimmedEmail, password: password, naam: naam.trimmingCharacters(in: .whitespacesAndNewlines))
            let response = try await client.authWithPassword(email: trimmedEmail, password: password)
            token = response.token
            tokenStore.save(response.token)
            justRegistered = true
            phase = .loggedIn(response.record)
        } catch {
            phase = .loggedOut(errorMessage: "Registreren mislukt — bestaat het account al?")
        }
    }

    /// Sluit de onboardingstap na registratie af (bedrijf gestart/toegetreden/overgeslagen).
    func finishOnboarding() {
        justRegistered = false
    }

    /// "Wachtwoord vergeten?" — geeft alleen terug of het lukte; de view toont zelf
    /// de Nederlandse Alert-tekst (zelfde als forgotPassword() in login.tsx).
    func requestPasswordReset(email: String) async -> Bool {
        do {
            try await client.requestPasswordReset(email: email.trimmingCharacters(in: .whitespacesAndNewlines))
            return true
        } catch {
            return false
        }
    }

    /// Valkuil I: onomkeerbaar. De view vraagt zelf om bevestiging vóórdat dit aangeroepen wordt.
    func deleteAccount() async throws {
        guard case .loggedIn(let user) = phase, let token else { return }
        try await client.deleteAccount(id: user.id, token: token)
        signOut()
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
