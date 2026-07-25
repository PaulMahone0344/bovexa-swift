import Foundation

/// Zoeken/sorteren van CompanyMember — zelfde algoritme als MemberSearchHelpers
/// (die op het kleinere `Member`-type werkt), hier voor de volledige ledenlijst
/// op de Bedrijf-tab. Losse implementatie i.p.v. hergebruik omdat de types niet
/// overlappen (zie modelkeuze in plak 1).
enum CompanyMemberSearchHelpers {
    static func toggleFavorite(_ userId: String, in favorites: [String]) -> [String] {
        favorites.contains(userId) ? favorites.filter { $0 != userId } : favorites + [userId]
    }

    /// Favorieten eerst, daarna alfabetisch op naam (of e-mail als naam ontbreekt).
    static func sortMembers(_ members: [CompanyMember], favorites: [String]) -> [CompanyMember] {
        members.sorted { a, b in
            let favA = favorites.contains(a.userId)
            let favB = favorites.contains(b.userId)
            if favA != favB { return favA }
            return label(a).compare(label(b), options: [.caseInsensitive], range: nil, locale: Locale(identifier: "nl")) == .orderedAscending
        }
    }

    /// Zoekt op naam én e-mail; lege term laat alles staan.
    static func filterMembers(_ members: [CompanyMember], query: String) -> [CompanyMember] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return members }
        return members.filter { "\($0.naam) \($0.email)".lowercased().contains(q) }
    }

    private static func label(_ member: CompanyMember) -> String {
        member.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
