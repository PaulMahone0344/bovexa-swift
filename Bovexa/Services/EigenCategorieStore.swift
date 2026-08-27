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
    /// Naam ⇒ kleur (hex). Aparte sleutel, zodat categorieën van vóór de kleuren
    /// gewoon blijven staan; die krijgen de standaardkleur.
    private static let kleurKey = "bovexaflow_eigen_categorie_kleuren"
    /// Vaste knoppen die de gebruiker heeft weggehaald. Ze bestaan nog wel als
    /// waarde (oude afspraken houden hun categorie), ze staan alleen niet meer
    /// in de rij.
    private static let verborgenKey = "bovexaflow_verborgen_vaste_categorieen"

    /// Grens op de rij knoppen: daarboven wordt de FlowLayout een muur van chips
    /// en is de vaste keuze niet meer terug te vinden.
    static let maxAantal = 8
    /// Past op één chip zonder de rij te laten omvallen.
    static let maxTekens = 20

    /// De vaste knoppen. Een eigen categorie met dezelfde naam zou een tweede,
    /// niet-werkende kopie naast de echte zetten.
    private static let vasteNamen = ["Werk", "Familie", "Sport", "Anders"]

    @Published private(set) var namen: [String]
    /// Kleur per categorie, als hex. Alleen om de knop te tekenen — de afspraak
    /// zelf gaat nog steeds onder `.focus` naar de server.
    @Published private(set) var kleuren: [String: String]
    /// Namen van vaste knoppen die niet meer in de rij horen.
    @Published private(set) var verborgenVast: Set<String>

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.namen = defaults.stringArray(forKey: Self.key) ?? []
        self.kleuren = defaults.dictionary(forKey: Self.kleurKey) as? [String: String] ?? [:]
        self.verborgenVast = Set(defaults.stringArray(forKey: Self.verborgenKey) ?? [])
    }

    /// Haalt een vaste knop uit de rij, of zet hem terug.
    func verbergVast(_ naam: String) {
        verborgenVast.insert(naam)
        bewaar()
    }

    func herstelVast(_ naam: String) {
        verborgenVast.remove(naam)
        bewaar()
    }

    func isVerborgen(_ naam: String) -> Bool {
        verborgenVast.contains(naam)
    }

    /// Kleur wijzigen van een bestaande eigen categorie.
    func zetKleur(_ kleur: String, voor naam: String) {
        guard namen.contains(naam) else { return }
        kleuren[naam] = kleur
        bewaar()
    }

    /// Hernoemen houdt de knop op zijn plek in de rij; de kleur verhuist mee.
    /// Geeft de bewaarde naam terug, of nil als de nieuwe naam leeg of bezet is.
    @discardableResult
    func hernoem(_ naam: String, naar nieuweNaam: String) -> String? {
        let schoon = String(nieuweNaam.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.maxTekens))
        guard !schoon.isEmpty, let index = namen.firstIndex(of: naam) else { return nil }
        if schoon.caseInsensitiveCompare(naam) != .orderedSame {
            guard !bestaat(schoon) else { return nil }
        }
        namen[index] = schoon
        if let kleur = kleuren[naam] {
            kleuren[naam] = nil
            kleuren[schoon] = kleur
        }
        bewaar()
        return schoon
    }

    /// Kleur van een eigen categorie; nil als er nog geen gekozen is.
    func kleur(voor naam: String) -> String? {
        kleuren[naam]
    }

    /// Slaat een nieuwe categorie op. Geeft de bewaarde naam terug, of nil als er
    /// niets toegevoegd is (leeg, dubbel, of de lijst zit vol) — de aanroeper
    /// gebruikt dat om de zojuist gemaakte knop meteen te selecteren.
    @discardableResult
    func voegToe(_ naam: String, kleur: String? = nil) -> String? {
        let schoon = String(naam.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.maxTekens))
        guard !schoon.isEmpty else { return nil }
        guard namen.count < Self.maxAantal else { return nil }
        // Hoofdletterongevoelig: "sport" naast "Sport" leest als één knop die
        // twee keer staat.
        guard !bestaat(schoon) else { return nil }

        namen.append(schoon)
        if let kleur, !kleur.isEmpty { kleuren[schoon] = kleur }
        bewaar()
        return schoon
    }

    func verwijder(_ naam: String) {
        namen.removeAll { $0.caseInsensitiveCompare(naam) == .orderedSame }
        kleuren = kleuren.filter { $0.key.caseInsensitiveCompare(naam) != .orderedSame }
        bewaar()
    }

    /// Of deze naam al bezet is — door een vaste knop of een eerder toegevoegde.
    func bestaat(_ naam: String) -> Bool {
        let schoon = naam.trimmingCharacters(in: .whitespacesAndNewlines)
        return (Self.vasteNamen + namen).contains { $0.caseInsensitiveCompare(schoon) == .orderedSame }
    }

    private func bewaar() {
        defaults.set(namen, forKey: Self.key)
        defaults.set(kleuren, forKey: Self.kleurKey)
        defaults.set(Array(verborgenVast), forKey: Self.verborgenKey)
    }
}
