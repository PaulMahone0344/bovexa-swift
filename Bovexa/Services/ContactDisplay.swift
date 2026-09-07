import Foundation

/// Wie hoort bij een afspraak (m8): het gekoppelde contact wint van de losse
/// tekst. Oude afspraken zonder contact (valkuil D) tonen gewoon hun klantnaam.
enum ContactDisplay {
    static func naam(for event: AgendaEvent) -> String? {
        if let contactNaam = event.expand?.contact?.naam, !contactNaam.isEmpty {
            return contactNaam
        }
        return event.klantNaam
    }

    /// Alle namen die bij de afspraak horen (punt 13a): eerst de klant, daarna de
    /// medegenodigden. Zonder uitgeklapte `contacten` — oude afspraak, of een fetch
    /// zonder expand — blijft het bij die ene regel die er altijd al stond.
    static func namen(for event: AgendaEvent) -> [String] {
        let uitgeklapt = event.expand?.contacten.map(\.naam).filter { !$0.isEmpty } ?? []
        guard !uitgeklapt.isEmpty else {
            return [naam(for: event)].compactMap { $0 }.filter { !$0.isEmpty }
        }
        return uitgeklapt
    }

    static func telefoon(for event: AgendaEvent) -> String? {
        if let contactTelefoon = event.expand?.contact?.telefoon, !contactTelefoon.isEmpty {
            return contactTelefoon
        }
        return event.klantTelefoon
    }
}
