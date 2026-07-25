import Foundation

/// Laatst-gezien-timestamp per gebruiker voor mededelingen — lokaal op het toestel,
/// zelfde patroon als FavoritesStore. Geport uit getLastSeen/markSeen in
/// ~/Desktop/agenda-app/src/lib/notices.ts (daar AsyncStorage, hier UserDefaults).
final class NoticesSeenStore {
    private static let keyPrefix = "bovexaflow_notices_seen_"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func lastSeen(userId: String) -> Date? {
        guard let raw = defaults.string(forKey: Self.keyPrefix + userId) else { return nil }
        return PBDate.parse(raw) ?? ISO8601DateFormatter().date(from: raw)
    }

    func markSeen(userId: String, at date: Date = Date()) {
        defaults.set(ISO8601DateFormatter().string(from: date), forKey: Self.keyPrefix + userId)
    }
}
