import Foundation

/// Onthoudt per account welke bedrijven het al eens open heeft gehad.
///
/// De server kan (nog) niet vertellen bij welke bedrijven een account hoort: er is
/// alleen `default_org`, dus precies één. Zolang `company/mine` er niet is, is dit
/// het enige geheugen dat de app heeft om een tweede bedrijf te kunnen tonen.
/// Komt die route er wel, dan is dit nog steeds nuttig als offline-lijst, maar
/// leidend is dan altijd het serverantwoord.
///
/// Per gebruiker opgeslagen, want een tweede account op hetzelfde toestel hoort
/// de bedrijven van het eerste niet te zien.
@MainActor
final class BekendeBedrijvenStore: ObservableObject {
    static let shared = BekendeBedrijvenStore()

    private static let keyPrefix = "bovexaflow_bekende_bedrijven_"

    @Published private(set) var bedrijven: [OrgSummary] = []

    private let defaults: UserDefaults
    private var userId: String?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Laadt de lijst van dit account. Bij een ander account begint de lijst leeg.
    func prime(userId: String) {
        guard self.userId != userId else { return }
        self.userId = userId
        bedrijven = lees(userId: userId)
    }

    /// Zet een bedrijf in de lijst, of werkt naam en logo bij als het er al staat.
    func onthoud(_ org: OrgSummary) {
        guard userId != nil else { return }
        if let index = bedrijven.firstIndex(where: { $0.id == org.id }) {
            guard bedrijven[index] != org else { return }
            bedrijven[index] = org
        } else {
            bedrijven.append(org)
        }
        schrijf()
    }

    /// Vervangt de hele lijst — gebruikt zodra `company/mine` wél antwoord geeft.
    func vervang(_ nieuwe: [OrgSummary]) {
        guard userId != nil, bedrijven != nieuwe else { return }
        bedrijven = nieuwe
        schrijf()
    }

    func vergeet(id: String) {
        guard userId != nil, bedrijven.contains(where: { $0.id == id }) else { return }
        bedrijven.removeAll { $0.id == id }
        schrijf()
    }

    /// Bij uitloggen: geheugen leegmaken zodat het volgende account schoon start.
    func wis() {
        if let userId { defaults.removeObject(forKey: Self.key(for: userId)) }
        userId = nil
        bedrijven = []
    }

    private func lees(userId: String) -> [OrgSummary] {
        guard let data = defaults.data(forKey: Self.key(for: userId)),
              let opgeslagen = try? JSONDecoder().decode([OrgSummary].self, from: data) else { return [] }
        return opgeslagen
    }

    private func schrijf() {
        guard let userId, let data = try? JSONEncoder().encode(bedrijven) else { return }
        defaults.set(data, forKey: Self.key(for: userId))
    }

    private static func key(for userId: String) -> String { keyPrefix + userId }
}
