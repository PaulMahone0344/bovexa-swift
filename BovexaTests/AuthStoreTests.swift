import Testing
import Foundation
@testable import Bovexa

@MainActor
struct AuthStoreTests {
    init() {
        URLProtocolStub.requestHandler = nil
    }

    private func makeClient() -> PBClient {
        PBClient(session: URLProtocolStub.makeSession())
    }

    @Test func bootstrapNoTokenGoesToLoggedOutWithoutError() async {
        let store = AuthStore(client: makeClient(), tokenStore: InMemoryTokenStore())
        await store.bootstrap()
        #expect(store.phase == .loggedOut(errorMessage: nil))
    }

    @Test func bootstrapValidTokenSilentlyRefreshesAndLogsIn() async {
        let tokenStore = InMemoryTokenStore()
        tokenStore.save("old-token")
        URLProtocolStub.requestHandler = { request in
            #expect(request.url!.absoluteString.contains("auth-refresh"))
            #expect(request.value(forHTTPHeaderField: "Authorization") == "old-token")
            let json = """
            {"token":"new-token","record":{"id":"u1","email":"a@b.nl","naam":"Ibrahim"}}
            """.data(using: .utf8)!
            return (200, json)
        }
        let store = AuthStore(client: makeClient(), tokenStore: tokenStore)
        await store.bootstrap()
        guard case .loggedIn(let user) = store.phase else {
            Issue.record("verwachtte loggedIn, kreeg \(store.phase)")
            return
        }
        #expect(user.id == "u1")
        #expect(tokenStore.load() == "new-token")
    }

    @Test func bootstrapExpiredTokenClearsTokenAndGoesToLoggedOutSilently() async {
        let tokenStore = InMemoryTokenStore()
        tokenStore.save("expired-token")
        URLProtocolStub.requestHandler = { _ in
            let json = """
            {"data":{},"message":"The request requires valid record authorization token.","status":401}
            """.data(using: .utf8)!
            return (401, json)
        }
        let store = AuthStore(client: makeClient(), tokenStore: tokenStore)
        await store.bootstrap()
        #expect(store.phase == .loggedOut(errorMessage: nil))
        #expect(tokenStore.load() == nil)
    }

    @Test func signInSuccessLogsInAndPersistsToken() async {
        URLProtocolStub.requestHandler = { request in
            #expect(request.url!.absoluteString.contains("auth-with-password"))
            let json = """
            {"token":"tok-1","record":{"id":"u1","email":"a@b.nl","naam":"Ibrahim"}}
            """.data(using: .utf8)!
            return (200, json)
        }
        let tokenStore = InMemoryTokenStore()
        let store = AuthStore(client: makeClient(), tokenStore: tokenStore)
        await store.signIn(email: "a@b.nl", password: "geheim123")
        guard case .loggedIn = store.phase else {
            Issue.record("verwachtte loggedIn, kreeg \(store.phase)")
            return
        }
        #expect(tokenStore.load() == "tok-1")
    }

    @Test func signInWrongCredentialsShowsDutchErrorAndStaysLoggedOut() async {
        URLProtocolStub.requestHandler = { _ in
            let json = """
            {"data":{},"message":"Failed to authenticate.","status":400}
            """.data(using: .utf8)!
            return (400, json)
        }
        let store = AuthStore(client: makeClient(), tokenStore: InMemoryTokenStore())
        await store.signIn(email: "a@b.nl", password: "fout")
        guard case .loggedOut(let message) = store.phase else {
            Issue.record("verwachtte loggedOut, kreeg \(store.phase)")
            return
        }
        #expect(message == "E-mailadres of wachtwoord onjuist.")
    }

    @Test func signInNetworkFailureShowsDutchNetworkError() async {
        URLProtocolStub.requestHandler = nil // geen handler → URLProtocolStub faalt met netwerkfout
        let store = AuthStore(client: makeClient(), tokenStore: InMemoryTokenStore())
        await store.signIn(email: "a@b.nl", password: "geheim123")
        guard case .loggedOut(let message) = store.phase else {
            Issue.record("verwachtte loggedOut, kreeg \(store.phase)")
            return
        }
        #expect(message == "Geen verbinding. Controleer je internet en probeer opnieuw.")
    }

    @Test func signOutClearsTokenAndReturnsToLoggedOut() async {
        let tokenStore = InMemoryTokenStore()
        tokenStore.save("tok")
        let store = AuthStore(client: makeClient(), tokenStore: tokenStore)
        store.signOut()
        #expect(store.phase == .loggedOut(errorMessage: nil))
        #expect(tokenStore.load() == nil)
    }

    // MARK: - Registratie (plak 1, valkuil A)

    @Test func signUpSuccessCreatesRecordThenLogsInAndMarksJustRegistered() async {
        var paths: [String] = []
        URLProtocolStub.requestHandler = { request in
            paths.append(request.url!.path)
            if request.url!.path.hasSuffix("/records") {
                let json = """
                {"id":"u1","email":"a@b.nl","naam":"Ibrahim"}
                """.data(using: .utf8)!
                return (200, json)
            }
            let json = """
            {"token":"tok-1","record":{"id":"u1","email":"a@b.nl","naam":"Ibrahim"}}
            """.data(using: .utf8)!
            return (200, json)
        }
        let tokenStore = InMemoryTokenStore()
        let store = AuthStore(client: makeClient(), tokenStore: tokenStore)
        await store.signUp(email: "a@b.nl", password: "geheim123", naam: "Ibrahim")
        guard case .loggedIn(let user) = store.phase else {
            Issue.record("verwachtte loggedIn, kreeg \(store.phase)")
            return
        }
        #expect(user.id == "u1")
        #expect(tokenStore.load() == "tok-1")
        #expect(store.justRegistered)
        #expect(paths.contains { $0.hasSuffix("/records") })
        #expect(paths.contains { $0.hasSuffix("/auth-with-password") })
    }

    @Test func signUpFailureShowsDutchErrorAndStaysLoggedOut() async {
        URLProtocolStub.requestHandler = { _ in
            let json = """
            {"data":{"email":{"message":"already taken"}},"message":"Failed to create record.","status":400}
            """.data(using: .utf8)!
            return (400, json)
        }
        let store = AuthStore(client: makeClient(), tokenStore: InMemoryTokenStore())
        await store.signUp(email: "a@b.nl", password: "geheim123", naam: "Ibrahim")
        guard case .loggedOut(let message) = store.phase else {
            Issue.record("verwachtte loggedOut, kreeg \(store.phase)")
            return
        }
        #expect(message == "Registreren mislukt — bestaat het account al?")
        #expect(!store.justRegistered)
    }

    @Test func finishOnboardingClearsJustRegistered() async {
        URLProtocolStub.requestHandler = { request in
            if request.url!.path.hasSuffix("/records") {
                return (200, """
                {"id":"u1","email":"a@b.nl","naam":"Ibrahim"}
                """.data(using: .utf8)!)
            }
            return (200, """
            {"token":"tok-1","record":{"id":"u1","email":"a@b.nl","naam":"Ibrahim"}}
            """.data(using: .utf8)!)
        }
        let store = AuthStore(client: makeClient(), tokenStore: InMemoryTokenStore())
        await store.signUp(email: "a@b.nl", password: "geheim123", naam: "Ibrahim")
        #expect(store.justRegistered)
        store.finishOnboarding()
        #expect(!store.justRegistered)
    }

    // MARK: - Wachtwoord vergeten

    @Test func requestPasswordResetSuccessReturnsTrue() async {
        URLProtocolStub.requestHandler = { request in
            #expect(request.url!.path.hasSuffix("/request-password-reset"))
            return (204, Data())
        }
        let store = AuthStore(client: makeClient(), tokenStore: InMemoryTokenStore())
        let success = await store.requestPasswordReset(email: "a@b.nl")
        #expect(success)
    }

    @Test func requestPasswordResetFailureReturnsFalse() async {
        URLProtocolStub.requestHandler = { _ in (400, Data()) }
        let store = AuthStore(client: makeClient(), tokenStore: InMemoryTokenStore())
        let success = await store.requestPasswordReset(email: "onbekend@b.nl")
        #expect(!success)
    }

    // MARK: - Account verwijderen (valkuil I)

    @Test func deleteAccountSendsDeleteThenSignsOut() async {
        let tokenStore = InMemoryTokenStore()
        tokenStore.save("tok")
        URLProtocolStub.requestHandler = { request in
            #expect(request.httpMethod == "DELETE")
            #expect(request.url!.path == "/api/collections/agenda_users/records/u1")
            return (204, Data())
        }
        let store = AuthStore(client: makeClient(), tokenStore: tokenStore)
        // In loggedIn komen via een geslaagde signIn.
        URLProtocolStub.requestHandler = { _ in
            (200, """
            {"token":"tok-1","record":{"id":"u1","email":"a@b.nl","naam":"Ibrahim"}}
            """.data(using: .utf8)!)
        }
        await store.signIn(email: "a@b.nl", password: "geheim123")
        URLProtocolStub.requestHandler = { request in
            #expect(request.httpMethod == "DELETE")
            #expect(request.url!.path == "/api/collections/agenda_users/records/u1")
            return (204, Data())
        }
        try? await store.deleteAccount()
        #expect(store.phase == .loggedOut(errorMessage: nil))
        #expect(tokenStore.load() == nil)
    }

    // MARK: - Profiel bewerken (valkuil J)

    @Test func updateProfileSendsMultipartPatchAndUpdatesPhase() async throws {
        let store = AuthStore(client: makeClient(), tokenStore: InMemoryTokenStore())
        URLProtocolStub.requestHandler = { _ in
            (200, """
            {"token":"tok-1","record":{"id":"u1","email":"a@b.nl","naam":"Ibrahim"}}
            """.data(using: .utf8)!)
        }
        await store.signIn(email: "a@b.nl", password: "geheim123")

        URLProtocolStub.requestHandler = { request in
            #expect(request.httpMethod == "PATCH")
            #expect(request.url!.path == "/api/collections/agenda_users/records/u1")
            let contentType = request.value(forHTTPHeaderField: "Content-Type") ?? ""
            #expect(contentType.hasPrefix("multipart/form-data"))
            return (200, """
            {"id":"u1","email":"a@b.nl","naam":"Ibrahim K.","avatar":"foto.jpg"}
            """.data(using: .utf8)!)
        }
        try await store.updateProfile(naam: "Ibrahim K.", avatar: nil)
        guard case .loggedIn(let user) = store.phase else {
            Issue.record("verwachtte loggedIn, kreeg \(store.phase)")
            return
        }
        #expect(user.naam == "Ibrahim K.")
        #expect(user.avatar == "foto.jpg")
    }

    // MARK: - Wachtwoord wijzigen (valkuil C)

    @Test func changePasswordUpdatesThenSilentlyRelogsInWithNewPassword() async throws {
        let store = AuthStore(client: makeClient(), tokenStore: InMemoryTokenStore())
        URLProtocolStub.requestHandler = { _ in
            (200, """
            {"token":"tok-oud","record":{"id":"u1","email":"a@b.nl","naam":"Ibrahim"}}
            """.data(using: .utf8)!)
        }
        await store.signIn(email: "a@b.nl", password: "oudwachtwoord")

        var sawPatch = false
        var sawReauth = false
        URLProtocolStub.requestHandler = { request in
            if request.httpMethod == "PATCH" {
                sawPatch = true
                #expect(request.url!.path == "/api/collections/agenda_users/records/u1")
                return (200, """
                {"id":"u1","email":"a@b.nl","naam":"Ibrahim"}
                """.data(using: .utf8)!)
            }
            sawReauth = true
            #expect(request.url!.path.hasSuffix("/auth-with-password"))
            return (200, """
            {"token":"tok-nieuw","record":{"id":"u1","email":"a@b.nl","naam":"Ibrahim"}}
            """.data(using: .utf8)!)
        }
        try await store.changePassword(current: "oudwachtwoord", new: "nieuwwachtwoord")

        #expect(sawPatch)
        #expect(sawReauth)
        guard case .loggedIn = store.phase else {
            Issue.record("verwachtte loggedIn, kreeg \(store.phase)")
            return
        }
    }

    @Test func changePasswordWrongCurrentThrowsAndKeepsOldToken() async throws {
        let tokenStore = InMemoryTokenStore()
        let store = AuthStore(client: makeClient(), tokenStore: tokenStore)
        URLProtocolStub.requestHandler = { _ in
            (200, """
            {"token":"tok-oud","record":{"id":"u1","email":"a@b.nl","naam":"Ibrahim"}}
            """.data(using: .utf8)!)
        }
        await store.signIn(email: "a@b.nl", password: "oudwachtwoord")

        URLProtocolStub.requestHandler = { _ in
            (400, """
            {"data":{},"message":"Failed to update record.","status":400}
            """.data(using: .utf8)!)
        }
        await #expect(throws: PBError.self) {
            try await store.changePassword(current: "fout", new: "nieuwwachtwoord")
        }
        #expect(tokenStore.load() == "tok-oud")
    }

    // MARK: - Offline starten (M11 plak 3a)

    private func makeDefaults() -> UserDefaults {
        let suiteName = "bovexa-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private static let loginResponse = """
    {"token":"tok-1","record":{"id":"u1","email":"a@b.nl","naam":"Ibrahim"}}
    """

    /// Vliegtuigstand aan en de app openen mocht geen uitlogactie zijn: bootstrap
    /// wiste het Keychain-token bij ÉLKE fout, dus ook zonder bereik.
    @Test func bootstrapWithoutConnectionKeepsTokenAndUsesTheCachedUser() async {
        let tokenStore = InMemoryTokenStore()
        let userCache = CachedUserStore(defaults: makeDefaults())

        URLProtocolStub.requestHandler = { _ in (200, Data(Self.loginResponse.utf8)) }
        let online = AuthStore(client: makeClient(), tokenStore: tokenStore, userCache: userCache)
        await online.signIn(email: "a@b.nl", password: "geheim123")
        #expect(userCache.load()?.id == "u1")

        // Geen handler = netwerkfout.
        URLProtocolStub.requestHandler = nil
        let offline = AuthStore(client: makeClient(), tokenStore: tokenStore, userCache: userCache)
        await offline.bootstrap()

        guard case .loggedIn(let user) = offline.phase else {
            Issue.record("verwachtte loggedIn uit de cache, kreeg \(offline.phase)")
            return
        }
        #expect(user.id == "u1")
        #expect(tokenStore.load() == "tok-1")
        #expect(offline.token == "tok-1")
    }

    @Test func bootstrapWithoutConnectionAndWithoutCacheKeepsTheTokenAndExplains() async {
        let tokenStore = InMemoryTokenStore()
        tokenStore.save("tok-1")
        URLProtocolStub.requestHandler = nil

        let store = AuthStore(client: makeClient(), tokenStore: tokenStore, userCache: CachedUserStore(defaults: makeDefaults()))
        await store.bootstrap()

        #expect(store.phase == .loggedOut(errorMessage: "Geen verbinding. Probeer het opnieuw."))
        // Het token is niet ongeldig, alleen onbereikbaar: niet wissen.
        #expect(tokenStore.load() == "tok-1")
    }

    @Test func bootstrapServerRejectionClearsTokenAndCache() async {
        let tokenStore = InMemoryTokenStore()
        let userCache = CachedUserStore(defaults: makeDefaults())

        URLProtocolStub.requestHandler = { _ in (200, Data(Self.loginResponse.utf8)) }
        let online = AuthStore(client: makeClient(), tokenStore: tokenStore, userCache: userCache)
        await online.signIn(email: "a@b.nl", password: "geheim123")

        URLProtocolStub.requestHandler = { _ in (401, Data("{}".utf8)) }
        let store = AuthStore(client: makeClient(), tokenStore: tokenStore, userCache: userCache)
        await store.bootstrap()

        #expect(store.phase == .loggedOut(errorMessage: nil))
        #expect(tokenStore.load() == nil)
        #expect(userCache.load() == nil)
    }

    @Test func signOutClearsTheCachedUser() async {
        let userCache = CachedUserStore(defaults: makeDefaults())
        URLProtocolStub.requestHandler = { _ in (200, Data(Self.loginResponse.utf8)) }
        let store = AuthStore(client: makeClient(), tokenStore: InMemoryTokenStore(), userCache: userCache)
        await store.signIn(email: "a@b.nl", password: "geheim123")
        #expect(userCache.load() != nil)

        store.signOut()
        #expect(userCache.load() == nil)
    }

    // MARK: - 401 tijdens gebruik (M11 plak 3b)

    @Test func unauthorizedDuringUseSignsOutWithAnExplanation() async {
        let tokenStore = InMemoryTokenStore()
        URLProtocolStub.requestHandler = { _ in (200, Data(Self.loginResponse.utf8)) }
        let store = AuthStore(
            client: makeClient(), tokenStore: tokenStore,
            userCache: CachedUserStore(defaults: makeDefaults()), notificationCenter: NotificationCenter()
        )
        await store.signIn(email: "a@b.nl", password: "geheim123")

        store.handleSessionExpired()

        #expect(store.phase == .loggedOut(errorMessage: "Je sessie is verlopen. Log opnieuw in."))
        #expect(tokenStore.load() == nil)
        #expect(store.token == nil)
    }

    /// Een 401 op de stille authRefresh tijdens app-start mag niet als "sessie
    /// verlopen" op het scherm komen: bootstrap handelt die zelf stil af.
    @Test func unauthorizedIsIgnoredWhileStillDeciding() {
        let store = AuthStore(
            client: makeClient(), tokenStore: InMemoryTokenStore(),
            userCache: CachedUserStore(defaults: makeDefaults()), notificationCenter: NotificationCenter()
        )
        #expect(store.phase == .deciding)
        store.handleSessionExpired()
        #expect(store.phase == .deciding)
    }

    @Test func pbClientPostsUnauthorizedOnA401() async {
        let center = NotificationCenter()
        let counter = PostCounter()
        let observer = center.addObserver(forName: .pbUnauthorized, object: nil, queue: nil) { _ in counter.bump() }
        defer { center.removeObserver(observer) }

        URLProtocolStub.requestHandler = { _ in (401, Data("{}".utf8)) }
        let client = PBClient(session: URLProtocolStub.makeSession(), notificationCenter: center)
        _ = try? await client.authRefresh(token: "dood")

        #expect(counter.count == 1)
    }

    @Test func pbClientDoesNotPostUnauthorizedOnOtherErrors() async {
        let center = NotificationCenter()
        let counter = PostCounter()
        let observer = center.addObserver(forName: .pbUnauthorized, object: nil, queue: nil) { _ in counter.bump() }
        defer { center.removeObserver(observer) }

        URLProtocolStub.requestHandler = { _ in (400, Data("{}".utf8)) }
        let client = PBClient(session: URLProtocolStub.makeSession(), notificationCenter: center)
        _ = try? await client.authRefresh(token: "tok")

        #expect(counter.count == 0)
    }

    // MARK: - Wachtwoord wijzigen, netwerkhik ná de wijziging (M11 plak 3h)

    /// De wijziging is dan al gelukt en PB heeft alle tokens ongeldig gemaakt.
    /// "Wijzigen mislukt" tonen en ingelogd blijven laat de gebruiker achter met
    /// een dood token: alles daarna geeft 401 en het oude wachtwoord werkt niet meer.
    @Test func changePasswordSignsOutWhenTheSecondLoginFails() async throws {
        let tokenStore = InMemoryTokenStore()
        URLProtocolStub.requestHandler = { _ in
            (200, Data("""
            {"token":"tok-oud","record":{"id":"u1","email":"a@b.nl","naam":"Ibrahim"}}
            """.utf8))
        }
        let store = AuthStore(
            client: makeClient(), tokenStore: tokenStore,
            userCache: CachedUserStore(defaults: makeDefaults())
        )
        await store.signIn(email: "a@b.nl", password: "oudwachtwoord")

        URLProtocolStub.requestHandler = { request in
            // De wijziging zelf lukt; het opnieuw inloggen erna niet.
            if request.url!.absoluteString.contains("auth-with-password") { return (500, Data("{}".utf8)) }
            return (200, Data("""
            {"id":"u1","email":"a@b.nl","naam":"Ibrahim"}
            """.utf8))
        }
        try await store.changePassword(current: "oudwachtwoord", new: "nieuwwachtwoord")

        #expect(store.phase == .loggedOut(errorMessage: "Wachtwoord gewijzigd — log opnieuw in met je nieuwe wachtwoord."))
        #expect(tokenStore.load() == nil)
    }
}

/// Kleine teller voor NotificationCenter-observers: een `var` in de testfunctie
/// vangen mag niet in een @Sendable closure.
final class PostCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    func bump() { lock.lock(); value += 1; lock.unlock() }
    var count: Int { lock.lock(); defer { lock.unlock() }; return value }
}
