import Foundation

/// Hoeveel is deze persoon ingezet? Zoekt de afspraken van één contact bij elkaar
/// en telt de uren op. Staat op het scherm "Persoon wijzigen", zodat je bij een
/// naam meteen ziet welke dagen hij stond ingepland en hoeveel uur dat was.
///
/// Er is geen aparte urenregistratie op de server (valkuil F, net als bij Klanten):
/// alles is afgeleid uit agenda_events. Een afspraak hoort bij dit contact als het
/// contact-id klopt, of — voor oude afspraken zonder koppeling (valkuil D) — als de
/// klantnaam gelijk is. Externe agenda's tellen niet mee: die komen niet uit dit
/// bedrijf en zeggen niets over de inzet van deze persoon (valkuil E).
enum ContactInzet {
    /// Eén dag waarop de persoon stond ingepland.
    struct Regel: Identifiable, Equatable {
        let id: String
        let titel: String
        let start: Date
        let einde: Date?
        let heleDag: Bool
        /// Onder de streep van "nu": de afspraak is voorbij en telt mee als geweest.
        let geweest: Bool

        /// Zonder eindtijd valt er niets te tellen — dat is een moment, geen duur.
        /// Een afspraak van een hele dag telt ook niet mee: hoe lang iemand er die
        /// dag was staat nergens, en acht of vierentwintig uur zou allebei gokwerk zijn.
        var minuten: Int {
            guard !heleDag, let einde else { return 0 }
            return max(0, Int(einde.timeIntervalSince(start) / 60))
        }
    }

    /// Alle afspraken van dit contact, de nieuwste bovenaan.
    static func regels(events: [AgendaEvent], contact: AgendaContact, now: Date) -> [Regel] {
        let naam = contact.naam.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return events
            .filter { event in
                guard !event.isExternal else { return false }
                if let contactId = event.contact, contactId == contact.id { return true }
                // Terugval voor afspraken van vóór de contactenkoppeling: alleen op
                // naam, en alleen als die naam er echt staat.
                guard !naam.isEmpty, event.contact?.isEmpty ?? true else { return false }
                let eventNaam = ContactDisplay.naam(for: event)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
                return eventNaam == naam
            }
            .map { event in
                Regel(
                    id: event.id,
                    titel: event.title,
                    start: event.start,
                    einde: event.end,
                    heleDag: event.allDay,
                    geweest: (event.end ?? event.start) < now
                )
            }
            .sorted { $0.start > $1.start }
    }

    static func minuten(_ regels: [Regel], geweest: Bool) -> Int {
        regels.filter { $0.geweest == geweest }.reduce(0) { $0 + $1.minuten }
    }

    /// "6 uur 30 min" — zelfde vorm als EventHelpers.durationLabel, maar dan voor
    /// een optelsom die makkelijk over de tien uur gaat.
    static func urenTekst(minuten: Int) -> String {
        guard minuten > 0 else { return "0 uur" }
        let uren = minuten / 60
        let rest = minuten % 60
        if uren == 0 { return "\(rest) min" }
        if rest == 0 { return "\(uren) uur" }
        return "\(uren) uur \(rest) min"
    }
}
