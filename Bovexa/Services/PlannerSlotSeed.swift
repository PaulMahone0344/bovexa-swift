import Foundation

/// Seed-tekst voor de planner vanaf een leeg uurslot of een lege dag — geport uit
/// formatPlannerSlotSeed() in ~/Desktop/agenda-app/src/lib/agendaSlots.ts.
enum PlannerSlotSeed {
    private static let weekdays = ["zondag", "maandag", "dinsdag", "woensdag", "donderdag", "vrijdag", "zaterdag"]
    private static let months = [
        "januari", "februari", "maart", "april", "mei", "juni",
        "juli", "augustus", "september", "oktober", "november", "december",
    ]

    /// "Plan op maandag 3 augustus 2026 om 09:00"
    static func forHour(_ hour: Int, on day: Date, calendar: Calendar = .current) -> String {
        "\(forDay(day, calendar: calendar)) om \(String(format: "%02d:00", hour))"
    }

    /// "Plan op maandag 3 augustus 2026" — zonder uur, voor als er alleen een dag
    /// gekozen is. De planner kiest dan zelf een tijd in plaats van een uur dat
    /// niemand genoemd heeft.
    static func forDay(_ day: Date, calendar: Calendar = .current) -> String {
        let comps = calendar.dateComponents([.year, .month, .day, .weekday], from: day)
        let weekday = weekdays[(comps.weekday ?? 1) - 1]
        let month = months[(comps.month ?? 1) - 1]
        return "Plan op \(weekday) \(comps.day ?? 0) \(month) \(comps.year ?? 0)"
    }
}
