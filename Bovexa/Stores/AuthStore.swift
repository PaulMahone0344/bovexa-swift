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
    /// Telt op bij elke terugkeer uit de achtergrond (M11 plak 3d). Vandaag,
    /// Agenda, Dagtaken en Profiel kijken hiernaar en verversen; zonder dit toonde
    /// de app 's ochtends nog de afspraken van gisteren.
    @Published private(set) var foregroundTick = 0

    private let client: PBClient
    private let tokenStore: TokenStore
    private let userCache: CachedUserStore
    private let notificationCenter: NotificationCenter
    private var unauthorizedObserver: NSObjectProtocol?

    init(
        client: PBClient = PBClient(),
        tokenStore: TokenStore = KeychainTokenStore(),
        userCache: CachedUserStore = CachedUserStore(),
        notificationCenter: NotificationCenter = .default
    ) {
        self.client = client
        self.tokenStore = tokenStore
        self.userCache = userCache
        self.notificationCenter = notificationCenter

        unauthorizedObserver = notificationCenter.addObserver(
            forName: .pbUnauthorized, object: nil, queue: nil
        ) { [weak self] _ in
            Task { @MainActor in self?.handleSessionExpired() }
        }
    }

    deinit {
        if let unauthorizedObserver {
            notificationCenter.removeObserver(unauthorizedObserver)
        }
    }

    /// Alleen zetten via deze weg, zodat de cache voor de offline-start (3a) nooit
    /// achterloopt op wat er op het scherm staat.
    private func setLoggedIn(_ user: AgendaUser) {
        userCache.save(user)
        phase = .loggedIn(user)
    }

    /// Een 401 tijdens gebruik (PBClient post `.pbUnauthorized`). Alleen zinvol als
    /// we dachten ingelogd te zijn: tijdens `bootstrap` staat de fase op `.deciding`
    /// en handelt die de 401 zelf stil af, en uitgelogd is er niets te doen.
    func handleSessionExpired() {
        guard case .loggedIn = phase else { return }
        tokenStore.clear()
        userCache.clear()
        token = nil
        phase = .loggedOut(errorMessage: "Je sessie is verlopen. Log opnieuw in.")
    }

    func markForeground() {
        foregroundTick += 1
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
            setLoggedIn(response.record)
        } catch {
            handleBootstrapFailure(error, savedToken: savedToken)
        }
    }

    /// Alleen een echte afwijzing van de server betekent dat het token dood is.
    /// Bij geen bereik (of een 5xx) hoort de app gewoon te openen: token laten
    /// staan en verder met het laatst bekende account. Vóór M11 wiste élke fout
    /// het token, dus vliegtuigstand aan + app openen = uitgelogd.
    private func handleBootstrapFailure(_ error: Error, savedToken: String) {
        if case .server(let status, _)? = error as? PBError, [400, 401, 403, 404].contains(status) {
            tokenStore.clear()
            userCache.clear()
            phase = .loggedOut(errorMessage: nil)
            return
        }

        if let cached = userCache.load() {
            token = savedToken
            phase = .loggedIn(cached)
            return
        }

        phase = .loggedOut(errorMessage: "Geen verbinding. Probeer het opnieuw.")
    }

    func signIn(email: String, password: String) async {
        do {
            let response = try await client.authWithPassword(email: email, password: password)
            token = response.token
            tokenStore.save(response.token)
            setLoggedIn(response.record)
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
            setLoggedIn(response.record)
        } catch {
            // Stil negeren — zie doc-comment hierboven.
        }
    }

    func signOut() {
        tokenStore.clear()
        userCache.clear()
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
            setLoggedIn(response.record)
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

    /// Profiel bewerken (valkuil J): server stuurt het volledige bijgewerkte
    /// record terug, dus geen aparte authRefresh nodig.
    func updateProfile(naam: String, avatar: PBClient.AvatarUpdate?) async throws {
        guard case .loggedIn(let user) = phase, let token else { return }
        let updated = try await client.updateProfile(id: user.id, naam: naam, avatar: avatar, token: token)
        setLoggedIn(updated)
    }

    /// Wachtwoord wijzigen (valkuil C): na de update is het oude token ongeldig —
    /// direct stil opnieuw inloggen zodat de gebruiker er niets van merkt.
    func changePassword(current: String, new: String) async throws {
        guard case .loggedIn(let user) = phase, let token else { return }
        _ = try await client.changePassword(id: user.id, oldPassword: current, newPassword: new, token: token)

        // Vanaf hier is het wachtwoord GEWIJZIGD en heeft PocketBase alle bestaande
        // tokens ongeldig gemaakt. Gooit de tweede stap een fout door, dan ziet de
        // gebruiker "Wijzigen mislukt" terwijl hij met een dood token achterblijft:
        // alles daarna geeft 401 en het oude wachtwoord werkt niet meer. Daarom
        // hier geen fout omhoog, maar netjes uitloggen met uitleg.
        do {
            let response = try await client.authWithPassword(email: user.email, password: new)
            self.token = response.token
            tokenStore.save(response.token)
            setLoggedIn(response.record)
        } catch {
            tokenStore.clear()
            userCache.clear()
            self.token = nil
            phase = .loggedOut(errorMessage: "Wachtwoord gewijzigd — log opnieuw in met je nieuwe wachtwoord.")
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
