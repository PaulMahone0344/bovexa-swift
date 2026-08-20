import SwiftUI

/// Vaste persoonskleur per teamlid — index op gesorteerde userId's uit de ledenlijst
/// (stabiel, geen opslag nodig). Hash-fallback voor ongeprimede/onbekende id's.
/// Algoritme + kleuren exact overgenomen uit ~/Desktop/agenda-app/src/lib/memberColor.ts.
final class MemberColors: ObservableObject {
    static let palette: [String] = [
        "#E05A5D", // rood
        "#E07B2E", // oranje
        "#C99A16", // goud
        "#8AA53C", // olijf
        "#3AA664", // groen
        "#2FA3A0", // zeegroen
        "#31A0C9", // lichtblauw
        "#3E87D6", // blauw
        "#6D6FD8", // indigo
        "#8E5BD1", // violet
        "#A264CE", // paars
        "#C75AC2", // magenta
        "#D45AA4", // roze
        "#B36B4A", // terracotta
    ]

    private var colorMap: [String: String] = [:]
    private var nameMap: [String: String] = [:]
    private(set) var orgName: String?
    /// Standaardduur van het bedrijf in minuten (M12), voor een nieuwe handmatige
    /// afspraak. Komt mee in dezelfde ledenlijst; nil zolang het bedrijf er geen
    /// heeft ingesteld.
    private(set) var orgDefaultDurationMin: Int?
    private(set) var members: [Member] = []

    func prime(members: [Member], org: CompanyOrgInfo? = nil) {
        let ids = Array(Set(members.map(\.userId))).sorted()
        for (index, id) in ids.enumerated() {
            colorMap[id] = Self.palette[index % Self.palette.count]
        }
        for member in members {
            let fallback = member.email.split(separator: "@").first.map(String.init) ?? member.email
            nameMap[member.userId] = member.naam.isEmpty ? fallback : member.naam
        }
        if let org, !org.name.isEmpty { orgName = org.name }
        // Zelfde voorzichtigheid als bij de naam: alleen overschrijven met iets
        // bruikbaars. 0 betekent op de server "niet ingesteld".
        if let duration = org?.defaultDurationMin, duration > 0 { orgDefaultDurationMin = duration }
        self.members = members
    }

    func colorHex(for userId: String?) -> String {
        guard let userId else { return Self.palette[0] }
        return colorMap[userId] ?? Self.hashColorHex(userId)
    }

    func color(for userId: String?) -> Color {
        Color(hex: colorHex(for: userId))
    }

    func firstName(for userId: String?) -> String? {
        guard let userId, let name = nameMap[userId] else { return nil }
        return name.split(separator: " ").first.map(String.init)
    }

    /// Randkleur voor een afspraak-kaart: alleen wanneer de afspraak van een ander is.
    func borderColorHex(owner: String?, me: String?) -> String? {
        guard let owner, let me, owner != me else { return nil }
        return colorHex(for: owner)
    }

    private static func hashColorHex(_ userId: String) -> String {
        var hash: UInt32 = 0
        for scalar in userId.unicodeScalars {
            hash = hash &* 31 &+ scalar.value
        }
        return palette[Int(hash) % palette.count]
    }
}
