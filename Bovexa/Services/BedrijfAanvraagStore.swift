import Foundation

/// Onthoudt op het toestel welke koppelingsaanvraag dit account heeft gedaan.
///
/// Een nieuw account mag sinds 25 augustus zelf geen bedrijf meer starten: het
/// vraagt koppeling aan en de beheerder handelt dat af. De server kent die
/// aanvraag nog niet als eigen lijst (zie MEERDERE-BEDRIJVEN-SERVER.txt), dus zonder
/// dit vroeg het scherm na elke herstart opnieuw om dezelfde aanvraag.
///
/// Per gebruiker apart, zoals PlanningNoteStore: op een gedeeld toestel hoort de
/// aanvraag van de één niet bij de ander te staan.
final class BedrijfAanvraagStore {
    private static let keyPrefix = "bovexaflow_bedrijf_aanvraag_"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private func key(_ userId: String) -> String { Self.keyPrefix + userId }

    /// Naam van het bedrijf waarvoor een aanvraag loopt, of nil als er geen is.
    func lees(userId: String) -> String? {
        guard !userId.isEmpty else { return nil }
        let waarde = defaults.string(forKey: key(userId)) ?? ""
        return waarde.isEmpty ? nil : waarde
    }

    func bewaar(naam: String, userId: String) {
        guard !userId.isEmpty else { return }
        defaults.set(naam, forKey: key(userId))
    }

    func wis(userId: String) {
        guard !userId.isEmpty else { return }
        defaults.removeObject(forKey: key(userId))
    }
}
