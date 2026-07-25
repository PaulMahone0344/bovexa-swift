import Foundation

/// Sorteren/filteren van collega's — geport uit ~/Desktop/agenda-app/src/lib/favorites.ts.
enum MemberSearchHelpers {
    static func toggleFavorite(_ userId: String, in favorites: [String]) -> [String] {
        favorites.contains(userId) ? favorites.filter { $0 != userId } : favorites + [userId]
    }

    /// Favorieten eerst, daarna alfabetisch op naam (of e-mail als naam ontbreekt).
    static func sortMembers(_ members: [Member], favorites: [String]) -> [Member] {
        members.sorted { a, b in
            let favA = favorites.contains(a.userId)
            let favB = favorites.contains(b.userId)
            if favA != favB { return favA }
            return label(a).compare(label(b), options: [.caseInsensitive], range: nil, locale: Locale(identifier: "nl")) == .orderedAscending
        }
    }

    /// Zoekt op naam én e-mail; lege term laat alles staan.
    static func filterMembers(_ members: [Member], query: String) -> [Member] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return members }
        return members.filter { "\($0.naam) \($0.email)".lowercased().contains(q) }
    }

    private static func label(_ member: Member) -> String {
        let raw = member.naam.isEmpty ? member.email : member.naam
        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
