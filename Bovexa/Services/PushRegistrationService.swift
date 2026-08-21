import Foundation
import UIKit

/// Abstractie over de APNs-registratie van UIApplication — testbaar zonder een
/// echt toestel (op de simulator komt er nooit een device-token binnen).
protocol RemoteNotificationRegistering: Sendable {
    func registerForRemoteNotifications()
}

/// De echte registratie. Vraagt zélf geen toestemming: registerForRemoteNotifications()
/// toont geen systeemprompt, dat doet alleen UNUserNotificationCenter. Zo krijgt
/// niemand een ongevraagde melding-vraag bij het inloggen (les uit m9, waar het
/// openen van Profiel ongevraagd om agendatoegang vroeg).
struct UIApplicationRegistrar: RemoteNotificationRegistering {
    func registerForRemoteNotifications() {
        Task { @MainActor in
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
}

/// Schrijft het APNs device-token weg op agenda_users.push_token, zodat
/// pb_hooks/agenda_push.pb.js weet waar hij naartoe moet.
///
/// De RN-app schreef hier een "ExponentPushToken[...]" in; de native app schrijft
/// het APNs-token als hex. De serverkant splitst op die vorm — laat het formaat
/// dus staan zoals Apple het geeft, zonder prefix of opmaak.
final class PushRegistrationService {
    private let client: PBClient
    private let registrar: RemoteNotificationRegistering?
    private let defaults: UserDefaults

    /// Laatst weggeschreven token, zodat een ongewijzigd token bij elke app-start
    /// geen PATCH kost. Apple levert hetzelfde token opnieuw aan bij iedere
    /// registratie, dus zonder deze check schrijft de app het elke keer weer.
    private static let lastTokenKey = "bovexaflow_last_push_token"

    init(
        client: PBClient = PBClient(),
        registrar: RemoteNotificationRegistering? = UIApplicationRegistrar(),
        defaults: UserDefaults = .standard
    ) {
        self.client = client
        self.registrar = registrar
        self.defaults = defaults
    }

    /// Vraagt iOS om een device-token. Roept dit pas aan als de gebruiker
    /// meldingen heeft toegestaan — registreren zonder toestemming levert wel een
    /// token op, maar geen zichtbare melding.
    func register() {
        registrar?.registerForRemoteNotifications()
    }

    /// Apple geeft het token als ruwe bytes; APNs verwacht het als hex.
    static func hexString(from deviceToken: Data) -> String {
        deviceToken.map { String(format: "%02x", $0) }.joined()
    }

    /// Slaat het token op als het afwijkt van wat er al staat. Fouten zijn stil:
    /// een mislukte tokenregistratie mag nooit een schermflow blokkeren.
    @discardableResult
    func store(deviceToken: Data, userId: String, token: String) async -> Bool {
        await store(hexToken: Self.hexString(from: deviceToken), userId: userId, token: token)
    }

    @discardableResult
    func store(hexToken: String, userId: String, token: String) async -> Bool {
        guard !hexToken.isEmpty else { return false }
        if defaults.string(forKey: Self.lastTokenKey) == hexToken { return false }
        do {
            _ = try await client.updateRecord(
                AgendaUser.self, collection: "agenda_users", id: userId,
                body: ["push_token": hexToken], token: token
            )
            defaults.set(hexToken, forKey: Self.lastTokenKey)
            return true
        } catch {
            return false
        }
    }

    /// Bij uitloggen: het token hoort niet bij de volgende gebruiker op dit
    /// toestel. Het veld op de server leegmaken doet de uitlogflow niet — daar is
    /// het token vaak al ongeldig — maar de lokale herinnering wél, zodat de
    /// volgende gebruiker zijn eigen record opnieuw laat vullen.
    func forgetLocalToken() {
        defaults.removeObject(forKey: Self.lastTokenKey)
    }
}
