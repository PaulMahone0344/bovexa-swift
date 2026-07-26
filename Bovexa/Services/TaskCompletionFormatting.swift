import Foundation

/// Tekst bij een afgevinkte dagtaak (m8, klantverzoek 26 juli): "Klaar om 14:32",
/// of bij een oudere dag "Klaar gisteren om 09:10". Geldt voor zowel lokale
/// dagtaken (PlanningNote) als team-dagtaken (AgendaTask).
enum TaskCompletionFormatting {
    static func label(completedAt: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        let time = timeString(completedAt)
        if calendar.isDateInToday(completedAt) {
            return "Klaar om \(time)"
        }
        if calendar.isDateInYesterday(completedAt) {
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
