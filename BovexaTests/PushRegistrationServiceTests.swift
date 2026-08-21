import Testing
import Foundation
@testable import Bovexa

final class FakeRemoteNotificationRegistrar: RemoteNotificationRegistering, @unchecked Sendable {
    private(set) var registerCount = 0
    func registerForRemoteNotifications() { registerCount += 1 }
}

/// PushRegistrationService — het APNs-token weghouden bij de serverkant zolang het
/// niet veranderd is, en de hex-vorm die pb_hooks gebruikt om Expo van APNs te
/// onderscheiden.
///
/// .serialized: deelt URLProtocolStub.requestHandler (static var) met de andere
/// netwerk-tests.
@Suite(.serialized)
struct PushRegistrationServiceTests {
    init() {
        URLProtocolStub.requestHandler = nil
        URLProtocolStub.errorHandler = nil
    }

    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "PushRegistrationServiceTests.\(UUID().uuidString)")!
    }

    private func makeService(
        registrar: FakeRemoteNotificationRegistrar = FakeRemoteNotificationRegistrar(),
        defaults: UserDefaults
    ) -> PushRegistrationService {
        PushRegistrationService(
            client: PBClient(session: URLProtocolStub.makeSession()),
            registrar: registrar, defaults: defaults
        )
    }

    private static let userRecord = """
    {"id":"u1","email":"a@b.nl","naam":"Ibrahim"}
    """

    // MARK: - hex-vorm

    /// De serverkant herkent een APNs-token aan "alleen hex"; een prefix of
    /// hoofdletters zouden hem naar het Expo-pad sturen.
    @Test func deviceTokenBecomesLowercaseHex() {
        let data = Data([0x00, 0x0f, 0xab, 0xff])
        #expect(PushRegistrationService.hexString(from: data) == "000fabff")
    }

    @Test func emptyDeviceTokenBecomesEmptyString() {
        #expect(PushRegistrationService.hexString(from: Data()) == "")
    }

    // MARK: - registreren

    @Test func registerAsksTheSystemForAToken() {
        let registrar = FakeRemoteNotificationRegistrar()
        let service = makeService(registrar: registrar, defaults: makeDefaults())
        service.register()
        #expect(registrar.registerCount == 1)
    }

    // MARK: - wegschrijven

    @Test func storeSendsThePatchToTheUserRecord() async {
        var method: String?
        var path: String?
        URLProtocolStub.requestHandler = { request in
            method = request.httpMethod
            path = request.url?.absoluteString
            return (200, Data(Self.userRecord.utf8))
        }
        let service = makeService(defaults: makeDefaults())
        let stored = await service.store(hexToken: "abc123abc123abc123abc123", userId: "u1", token: "tok")
        #expect(stored)
        #expect(method == "PATCH")
        #expect(path?.contains("/api/collections/agenda_users/records/u1") == true)
    }

    /// Apple levert bij élke registratie hetzelfde token opnieuw aan; zonder deze
    /// check zou de app bij iedere start een PATCH doen.
    @Test func storeSkipsAnUnchangedToken() async {
        var calls = 0
        URLProtocolStub.requestHandler = { _ in
            calls += 1
            return (200, Data(Self.userRecord.utf8))
        }
        let defaults = makeDefaults()
        let service = makeService(defaults: defaults)
        _ = await service.store(hexToken: "abc123abc123abc123abc123", userId: "u1", token: "tok")
        let second = await service.store(hexToken: "abc123abc123abc123abc123", userId: "u1", token: "tok")
        #expect(second == false)
        #expect(calls == 1)
    }

    @Test func storeSendsAgainWhenTheTokenChanges() async {
        var calls = 0
        URLProtocolStub.requestHandler = { _ in
            calls += 1
            return (200, Data(Self.userRecord.utf8))
        }
        let defaults = makeDefaults()
        let service = makeService(defaults: defaults)
        _ = await service.store(hexToken: "abc123abc123abc123abc123", userId: "u1", token: "tok")
        _ = await service.store(hexToken: "def456def456def456def456", userId: "u1", token: "tok")
        #expect(calls == 2)
    }

    @Test func storeIgnoresAnEmptyToken() async {
        URLProtocolStub.requestHandler = { _ in
            Issue.record("mocht geen netwerkverzoek doen")
            return (500, Data())
        }
        let service = makeService(defaults: makeDefaults())
        let stored = await service.store(hexToken: "", userId: "u1", token: "tok")
        #expect(stored == false)
    }

    /// Een mislukte tokenregistratie mag nooit een schermflow blokkeren: stil falen,
    /// en het token niet als "opgeslagen" onthouden zodat de volgende poging het
    /// opnieuw probeert.
    @Test func aFailedStoreIsSilentAndRetriesNextTime() async {
        var calls = 0
        URLProtocolStub.requestHandler = { _ in
            calls += 1
            return (400, Data())
        }
        let defaults = makeDefaults()
        let service = makeService(defaults: defaults)
        let first = await service.store(hexToken: "abc123abc123abc123abc123", userId: "u1", token: "tok")
        #expect(first == false)

        URLProtocolStub.requestHandler = { _ in
            calls += 1
            return (200, Data(Self.userRecord.utf8))
        }
        let second = await service.store(hexToken: "abc123abc123abc123abc123", userId: "u1", token: "tok")
        #expect(second)
        #expect(calls == 2)
    }

    /// Uitloggen: de volgende gebruiker op dit toestel moet zijn eigen record
    /// laten vullen, dus de lokale herinnering gaat weg.
    @Test func forgetLocalTokenMakesTheNextStoreSendAgain() async {
        var calls = 0
        URLProtocolStub.requestHandler = { _ in
            calls += 1
            return (200, Data(Self.userRecord.utf8))
        }
        let defaults = makeDefaults()
        let service = makeService(defaults: defaults)
        _ = await service.store(hexToken: "abc123abc123abc123abc123", userId: "u1", token: "tok")
        service.forgetLocalToken()
        _ = await service.store(hexToken: "abc123abc123abc123abc123", userId: "u2", token: "tok")
        #expect(calls == 2)
    }
}
