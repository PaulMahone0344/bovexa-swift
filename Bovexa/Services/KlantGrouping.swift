import Foundation

/// Groepeert afspraken op wie erbij hoort (valkuil F/G): een gekoppeld contact
/// (m8) wint van de losse klantnaam-tekst — zie ContactDisplay. Omdat een contact
/// altijd dezelfde naam oplevert, lost dit meteen het dubbele-kaarten-probleem bij
/// tikfouten op voor elke afspraak die een contact heeft. Geport uit groupByKlant
/// in ~/Desktop/agenda-app/src/lib/events.ts. Afspraken zonder naam (leeg, of
/// gemaskeerd door de server, valkuil G) horen niet in de lijst.
enum KlantGrouping {
    static func group(_ events: [AgendaEvent]) -> [KlantGroup] {
        var order: [String] = []
        var names: [String: String] = [:]
        var phones: [String: String] = [:]
        var eventsByKey: [String: [AgendaEvent]] = [:]

        for event in events {
            // Valkuil E: een externe agenda is geen klant, ook niet als er toevallig
            // een klantnaam op het event zou staan.
            guard !event.isExternal else { continue }
            guard let naam = ContactDisplay.naam(for: event)?.trimmingCharacters(in: .whitespacesAndNewlines), !naam.isEmpty else { continue }
            let key = naam.lowercased()
            if names[key] == nil {
                order.append(key)
                names[key] = naam
                eventsByKey[key] = []
            }
            if phones[key] == nil, let phone = ContactDisplay.telefoon(for: event), !phone.isEmpty {
                phones[key] = phone
            }
            eventsByKey[key, default: []].append(event)
        }

        return order
            .map { key in
                KlantGroup(
                    naam: names[key]!,
                    telefoon: phones[key],
                    events: (eventsByKey[key] ?? []).sorted { $0.start < $1.start }
                )
            }
            .sorted { $0.naam.localizedStandardCompare($1.naam) == .orderedAscending }
    }

    /// Splitst de afspraken van één klant rond een vast moment — "Komend" oplopend,
    /// "Eerder" met de meest recente eerst (klanten.tsx: `past.slice().reverse()`).
    static func split(_ events: [AgendaEvent], now: Date) -> (upcoming: [AgendaEvent], past: [AgendaEvent]) {
        let upcoming = events.filter { ($0.end ?? $0.start) >= now }
        let past = events.filter { ($0.end ?? $0.start) < now }.reversed()
        return (upcoming, Array(past))
    }
}
