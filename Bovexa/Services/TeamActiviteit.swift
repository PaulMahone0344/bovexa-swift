import Foundation

/// Wat het team recent heeft ingevoerd. De beheerder ziet in Meldingen alleen wat
/// aan hem gericht is (een toewijzing, een mededeling); alles wat medewerkers
/// verder in de agenda zetten — een training, een vrije dag, een klantafspraak —
/// kwam nergens langs. Deze lijst vult dat gat: één overzicht van wat er nieuw is
/// bijgekomen, zodat je niet elke agenda apart hoeft na te lopen.
enum TeamActiviteit {
    /// Hoe ver terug we kijken. Verder terug maakt de lijst een archief in plaats
    /// van een meldingenlijst.
    static let vensterDagen = 14
    /// Bovengrens, zodat een druk team het scherm niet vult met honderd regels.
    static let maximum = 25

    /// Afspraken die iemand anders binnen hetzelfde bedrijf heeft aangemaakt,
    /// nieuwste invoer eerst.
    ///
    /// - Eigen afspraken vallen af: je hoeft geen melding van jezelf.
    /// - Alleen records met een `org` die gelijk is aan het eigen bedrijf, zodat
    ///   privé-afspraken van collega's er nooit tussen staan.
    /// - Herhalingen tellen één keer mee: de uitgeklapte bezettingen delen hun
    ///   record-id, en dertig regels "elke week training" is geen melding.
    static func recent(
        _ events: [AgendaEvent], userId: String, orgId: String?, now: Date,
        calendar: Calendar = .current
    ) -> [AgendaEvent] {
        guard let orgId, !orgId.isEmpty else { return [] }
        guard let grens = calendar.date(byAdding: .day, value: -vensterDagen, to: now) else { return [] }

        var gezien = Set<String>()
        var resultaat: [AgendaEvent] = []

        for event in events.sorted(by: { ($0.created ?? .distantPast) > ($1.created ?? .distantPast) }) {
            guard event.owner != userId else { continue }
            guard event.org == orgId else { continue }
            guard let created = event.created, created >= grens else { continue }
            let sleutel = EventHelpers.eventRecordId(event)
            guard !gezien.contains(sleutel) else { continue }
            gezien.insert(sleutel)
            resultaat.append(event)
            if resultaat.count >= maximum { break }
        }
        return resultaat
    }

    /// Regeltekst onder de titel: wie het invoerde en wanneer het staat gepland.
    static func omschrijving(_ event: AgendaEvent, naam: String, calendar: Calendar = .current) -> String {
        let wie = naam.trimmingCharacters(in: .whitespacesAndNewlines)
        let wanneer = EventHelpers.longDay(event.start, calendar: calendar)
        if event.allDay {
            return wie.isEmpty ? wanneer : "\(wie) · \(wanneer)"
        }
        let tijd = EventHelpers.fmtTime(event.start)
        let basis = "\(wanneer) om \(tijd)"
        return wie.isEmpty ? basis : "\(wie) · \(basis)"
    }
}
