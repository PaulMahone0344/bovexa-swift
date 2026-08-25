import Foundation

/// Zelfbedachte categorieën uit de knop "Anders" in het afsprakenformulier.
///
/// Alleen op dít toestel (UserDefaults). Het serverveld `category` kent enkel de
/// vaste waarden van `BovexaTheme.Category`; een vrij verzonnen naam past daar
/// niet in. Een eigen categorie wordt daarom bewaard als knop, en de afspraak
/// zelf gaat onder de vaste waarde `.focus` naar de server — die is sinds de
/// hernoeming (Werk/Familie/Sport) niet meer als knop in gebruik, dus hij botst
/// met niets.
///
/// Volgorde = volgorde van toevoegen. Het formulier zet "Anders" altijd achteraan,
/// dus een nieuwe categorie komt vanzelf links van die knop te staan.
@MainActor
final class EigenCategorieStore: ObservableObject {
    /// Eén lijst voor de hele app: het formulier wordt op meerdere plekken geopend
    /// (dagsheet, long-press op een uur, bewerken vanuit het detail) en overal
    /// horen dezelfde knoppen te staan.
    static let shared = EigenCategorieStore()

    private static let key = "bovexaflow_eigen_categorieen"

    /// Grens op de rij knoppen: daarboven wordt de FlowLayout een muur van chips
    /// en is de vaste keuze niet meer terug te vinden.
    static let maxAantal = 8
    /// Past op één chip zonder de rij te laten omvallen.
    static let maxTekens = 20

    /// De vaste knoppen. Een eigen categorie met dezelfde naam zou een tweede,
    /// niet-werkende kopie naast de echte zetten.
    private static let vasteNamen = ["Werk", "Familie", "Sport", "Anders"]

    @Published private(set) var namen: [String]

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.namen = defaults.stringArray(forKey: Self.key) ?? []
    }

    /// Slaat een nieuwe categorie op. Geeft de bewaarde naam terug, of nil als er
    /// niets toegevoegd is (leeg, dubbel, of de lijst zit vol) — de aanroeper
    /// gebruikt dat om de zojuist gemaakte knop meteen te selecteren.
    @discardableResult
    func voegToe(_ naam: String) -> String? {
        let schoon = String(naam.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.maxTekens))
        guard !schoon.isEmpty else { return nil }
        guard namen.count < Self.maxAantal else { return nil }
        // Hoofdletterongevoelig: "sport" naast "Sport" leest als één knop die
        // twee keer staat.
        guard !bestaat(schoon) else { return nil }

        namen.append(schoon)
        bewaar()
        return schoon
    }

    func verwijder(_ naam: String) {
        namen.removeAll { $0.caseInsensitiveCompare(naam) == .orderedSame }
        bewaar()
    }

    /// Of deze naam al bezet is — door een vaste knop of een eerder toegevoegde.
    func bestaat(_ naam: String) -> Bool {
        let schoon = naam.trimmingCharacters(in: .whitespacesAndNewlines)
        return (Self.vasteNamen + namen).contains { $0.caseInsensitiveCompare(schoon) == .orderedSame }
    }

    private func bewaar() {
        defaults.set(namen, forKey: Self.key)
    }
}
