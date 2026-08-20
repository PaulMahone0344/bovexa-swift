import Foundation

/// Laatst bekende account, in UserDefaults. Bestaat alleen om de app te kunnen
/// openen zonder bereik (M11 plak 3a): het token staat in de Keychain, maar
/// zonder een `AgendaUser` kan RootRouterView geen tabs tonen en belandde je op
/// het loginscherm zodra de stille authRefresh niet door kwam.
///
/// Bewust géén Keychain: dit is geen geheim, het is een kopie van wat de server
/// toch al teruggeeft. Het token blijft wél in de Keychain.
final class CachedUserStore {
    private static let key = "bovexaflow_cached_user"

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> AgendaUser? {
        guard let data = defaults.data(forKey: Self.key) else { return nil }
        return try? decoder.decode(AgendaUser.self, from: data)
    }

    func save(_ user: AgendaUser) {
        guard let data = try? encoder.encode(user) else { return }
        defaults.set(data, forKey: Self.key)
    }

    func clear() {
        defaults.removeObject(forKey: Self.key)
    }
}
