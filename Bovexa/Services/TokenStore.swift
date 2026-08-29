import Foundation

protocol TokenStore {
    func load() -> String?
    func save(_ token: String)
    func clear()
}

/// Kiest de juiste opslag per omgeving. Op een toestel hoort het token in de
/// Keychain (veilig, overleeft herstarts). In de simulator wist elke
/// herinstallatie van de ongesigneerde debug-build de Keychain, waardoor je bij
/// elke nieuwe build opnieuw moest inloggen — daar is UserDefaults de werkbare
/// keuze, en veiligheid speelt in de simulator niet.
enum TokenStores {
    static func standaard() -> TokenStore {
        #if targetEnvironment(simulator)
        SimulatorTokenStore()
        #else
        KeychainTokenStore()
        #endif
    }
}

/// Alleen voor de simulator — zie TokenStores.standaard().
struct SimulatorTokenStore: TokenStore {
    private static let key = "bovexaflow_sim_token"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> String? { defaults.string(forKey: Self.key) }
    func save(_ token: String) { defaults.set(token, forKey: Self.key) }
    func clear() { defaults.removeObject(forKey: Self.key) }
}
