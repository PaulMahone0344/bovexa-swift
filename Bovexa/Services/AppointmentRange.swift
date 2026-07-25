import Foundation

/// Datumopbouw voor AI-voorstellen — geport uit composeDate()/appointmentRange() in
/// ~/Desktop/agenda-app/src/lib/aiPlanner.ts.
enum AppointmentRange {
    /// Lokale Date uit "YYYY-MM-DD" + "HH:MM" (device-tijdzone, net als de rest van de app).
    static func composeDate(date: String, time: String, calendar: Calendar = .current) -> Date {
        let dateParts = date.split(separator: "-").compactMap { Int($0) }
        let timeParts = time.split(separator: ":").compactMap { Int($0) }
        var components = DateComponents()
        components.year = dateParts.count > 0 ? dateParts[0] : 1970
        components.month = dateParts.count > 1 ? dateParts[1] : 1
        components.day = dateParts.count > 2 ? dateParts[2] : 1
        components.hour = timeParts.count > 0 ? timeParts[0] : 0
        components.minute = timeParts.count > 1 ? timeParts[1] : 0
        components.second = 0
        return calendar.date(from: components) ?? Date(timeIntervalSince1970: 0)
    }

    /// Start/eind voor een voorgesteld voorstel. Valkuil E: eindtijd vóór starttijd
    /// (over middernacht) → eind schuift één dag op.
    static func range(for appointment: ProposedAppointment, calendar: Calendar = .current) -> (start: Date, end: Date) {
        let start = composeDate(date: appointment.date, time: appointment.start, calendar: calendar)
        var end = composeDate(date: appointment.date, time: appointment.end, calendar: calendar)
        if end <= start {
            end = calendar.date(byAdding: .day, value: 1, to: end) ?? end
        }
        return (start, end)
    }
}
