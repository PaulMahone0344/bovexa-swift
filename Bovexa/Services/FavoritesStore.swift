import Foundation

/// Favoriete collega's per gebruiker — lokaal op het toestel, geen server-schema.
/// Zelfde sleutelgedrag als de RN-app: bovexaflow_favoriete_collegas_<userId>.
final class FavoritesStore {
    private static let keyPrefix = "bovexaflow_favoriete_collegas_"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load(userId: String) -> [String] {
        defaults.stringArray(forKey: Self.keyPrefix + userId) ?? []
    }

    func save(_ ids: [String], userId: String) {
        defaults.set(ids, forKey: Self.keyPrefix + userId)
    }
}
