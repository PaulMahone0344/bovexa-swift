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
}
