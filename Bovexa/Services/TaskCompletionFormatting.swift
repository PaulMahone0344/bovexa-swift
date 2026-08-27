import Foundation

/// Tekst bij een afgevinkte dagtaak (m8, klantverzoek 26 juli): "Klaar om 14:32",
/// of bij een oudere dag "Klaar gisteren om 09:10". Geldt voor zowel lokale
/// dagtaken (PlanningNote) als team-dagtaken (AgendaTask).
enum TaskCompletionFormatting {
    /// Met `door` erbij: "Gedaan door Ayman om 14:32" — dat is wat de beheerder
    /// wil zien bij een taak die hij aan iemand heeft gegeven. Zonder naam blijft
    /// het de oude tekst.
    static func label(completedAt: Date, door: String, now: Date = Date(), calendar: Calendar = .current) -> String {
        let basis = label(completedAt: completedAt, now: now, calendar: calendar)
        guard !door.isEmpty else { return basis }
        let staart = basis.replacingOccurrences(of: "Klaar ", with: "")
        return door == "Jij" ? "Door jou gedaan \(staart)" : "Gedaan door \(door) \(staart)"
    }

    static func label(completedAt: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        let time = timeString(completedAt)
        // Vergelijken met `now` en niet met de systeemklok (isDateInToday): die
        // parameter werd genegeerd, dus wie de app om middernacht open had staan
        // zag "Klaar om 23:50" over een taak van de vorige dag.
        if calendar.isDate(completedAt, inSameDayAs: now) {
            return "Klaar om \(time)"
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(completedAt, inSameDayAs: yesterday) {
            return "Klaar gisteren om \(time)"
        }
        return "Klaar \(dayString(completedAt)) om \(time)"
    }

    private static func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nl_NL")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private static func dayString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nl_NL")
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }
}
