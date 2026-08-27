import Foundation

/// Onthoudt bij welk bedrijf een contact hoort, zolang `agenda_contacten` op de
/// server nog geen veld `org` heeft (zie MEERDERE-BEDRIJVEN-SERVER.txt). De app
/// stuurt `org` al mee bij het aanmaken; PocketBase laat het vallen, waardoor een
/// bedrijfspersoon bij Privé belandde. Deze lijst houdt de indeling op dit toestel
/// overeind. Zodra het serverveld er is, wint dat veld en mag dit weg.
@MainActor
final class ContactOrgStore: ObservableObject {
    static let shared = ContactOrgStore()

    private static let keyPrefix = "bovexaflow_contact_org_"

    /// contact-id ⇒ org-id. Alleen bedrijfscontacten staan erin; privé is de
    /// afwezigheid van een regel, niet een lege waarde.
    @Published private(set) var koppelingen: [String: String] = [:]

    private var userId: String = ""
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Per gebruiker een eigen lijst: op een gedeeld toestel hoort de indeling van
    /// de een niet bij de ander.
    func prime(userId: String) {
        guard self.userId != userId else { return }
        self.userId = userId
        koppelingen = laad()
    }

    func org(voor contactId: String) -> String {
        koppelingen[contactId] ?? ""
    }

    func zet(contactId: String, org: String) {
        guard !contactId.isEmpty else { return }
        if org.isEmpty {
            koppelingen.removeValue(forKey: contactId)
        } else {
            koppelingen[contactId] = org
        }
        bewaar()
    }

    func vergeet(contactId: String) {
        guard koppelingen.removeValue(forKey: contactId) != nil else { return }
        bewaar()
    }

    private var key: String { Self.keyPrefix + userId }

    private func laad() -> [String: String] {
        guard !userId.isEmpty,
              let data = defaults.data(forKey: key),
              let waarden = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
        return waarden
    }

    private func bewaar() {
        guard !userId.isEmpty, let data = try? JSONEncoder().encode(koppelingen) else { return }
        defaults.set(data, forKey: key)
    }
}
