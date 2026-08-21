import Foundation

/// Brievenbus tussen de AppDelegate en de SwiftUI-kant.
///
/// APNs levert het device-token asynchroon bij de UIApplicationDelegate af — die
/// kent de ingelogde gebruiker niet en kan er dus niets mee. De delegate legt het
/// hier neer; RootRouterView pakt het op zodra er een gebruiker én een token is.
/// Andersom kan de volgorde ook zijn: de gebruiker is er eerder dan het token, dus
/// beide kanten kijken bij elke wijziging opnieuw.
@MainActor
final class PushTokenInbox: ObservableObject {
    static let shared = PushTokenInbox()

    /// Het APNs device-token als hex, of nil zolang iOS er nog geen gegeven heeft.
    /// Blijft nil op de simulator en als de gebruiker meldingen weigert.
    @Published private(set) var hexToken: String?

    private init() {}

    func deliver(deviceToken: Data) {
        hexToken = PushRegistrationService.hexString(from: deviceToken)
    }

    /// Registratie mislukt (geen netwerk, geen aps-entitlement, simulator). Stil
    /// laten: zonder token stuurt de server gewoon niets naar dit toestel.
    func deliverFailure() {
        hexToken = nil
    }
}
