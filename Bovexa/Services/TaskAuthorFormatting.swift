import Foundation

/// Wie de dagtaak heeft gezet en wanneer. In de rij kort ("Karim · 09:10"), in het
/// detailscherm met de dag erbij — een tijd zonder dag zegt niets zodra de taak een
/// paar dagen blijft staan.
enum TaskAuthorFormatting {
    static func label(owner: String, created: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        "\(owner) · \(whenText(created, now: now, calendar: calendar))"
    }

    static func shortLabel(owner: String, created: Date) -> String {
        "\(owner) · \(timeString(created))"
    }

    private static func whenText(_ date: Date, now: Date, calendar: Calendar) -> String {
        let time = timeString(date)
        if calendar.isDate(date, inSameDayAs: now) {
            return "vandaag om \(time)"
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return "gisteren om \(time)"
        }
        return "\(dayString(date)) om \(time)"
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
