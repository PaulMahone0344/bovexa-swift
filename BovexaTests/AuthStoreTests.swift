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
}
