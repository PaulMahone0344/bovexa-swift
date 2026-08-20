import Foundation

/// Voorzet voor "Nieuwe afspraak" (M12): waar de gebruiker vandaan kwam — een
/// aangewezen dag (dagsheet), een aangewezen leeg uur (long-press) of een
/// getypte/gesproken zin (plan-pill of de AI-kaart).
///
/// Eén bron, twee vertalingen: de AI-route krijgt er een planner-zin uit
/// (`plannerSeed`), het handmatige formulier een starttijd (`startDate`). Zo
/// staat de vertaalregel op één plek in plaats van bij elke ingang opnieuw.
struct NieuweAfspraakSeed: Equatable {
    /// Aangewezen dag. Alleen de kalenderdag telt; het tijdstip erin wordt genegeerd.
    let date: Date?
    /// Aangewezen uur (0-23), alleen bij een long-press op een leeg uurslot.
    /// Zonder `date` betekenisloos — dan is er geen dag om het uur op te zetten.
    let hour: Int?
    /// Getypte of gesproken tekst.
    let text: String?

    /// Uur waarop het handmatige formulier opent als er wél een dag maar geen uur
    /// is aangewezen: het begin van een werkdag.
    private static let defaultHour = 9

    init(date: Date? = nil, hour: Int? = nil, text: String? = nil) {
        self.date = date
        self.hour = hour
        self.text = text
    }

    static let empty = NieuweAfspraakSeed()

    static func forDay(_ day: Date) -> NieuweAfspraakSeed {
        NieuweAfspraakSeed(date: day)
    }

    static func forHour(_ hour: Int, on day: Date) -> NieuweAfspraakSeed {
        NieuweAfspraakSeed(date: day, hour: hour)
    }

    static func typed(_ text: String) -> NieuweAfspraakSeed {
        NieuweAfspraakSeed(text: text)
    }

    /// Getypte tekst zonder witruimte eromheen; leeg of alleen spaties ⇒ nil.
    var trimmedText: String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed
    }

    /// De zin waarmee de AI-planner opent. Getypte tekst wint: die is specifieker
    /// dan de dag waar de gebruiker toevallig vandaan kwam. Nil ⇒ planner opent
    /// met zijn startkaart, zonder eerste beurt.
    func plannerSeed(calendar: Calendar = .current) -> String? {
        if let trimmedText { return trimmedText }
        guard let date else { return nil }
        if let hour { return PlannerSlotSeed.forHour(hour, on: date, calendar: calendar) }
        return PlannerSlotSeed.forDay(date, calendar: calendar)
    }

    /// Starttijd waarmee het handmatige formulier opent: het aangewezen uur op de
    /// aangewezen dag, anders 09:00 op die dag, anders het eerstvolgende hele uur
    /// vanaf nu (getypte tekst zegt niets over de datum — die leest alleen de AI).
    func startDate(now: Date = Date(), calendar: Calendar = .current) -> Date {
        guard let date else { return Self.nextWholeHour(after: now, calendar: calendar) }
        let hourOfDay = min(max(hour ?? Self.defaultHour, 0), 23)
        return calendar.date(bySettingHour: hourOfDay, minute: 0, second: 0, of: date) ?? date
    }

    private static func nextWholeHour(after now: Date, calendar: Calendar) -> Date {
        var comps = calendar.dateComponents([.year, .month, .day, .hour], from: now)
        comps.minute = 0
        comps.second = 0
        let onTheHour = calendar.date(from: comps) ?? now
        return calendar.date(byAdding: .hour, value: 1, to: onTheHour) ?? onTheHour
    }
}
