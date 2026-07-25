import Foundation

/// Ongelezen-check en relatieve tijd voor mededelingen — geport uit
/// hasUnread/relativeTime in ~/Desktop/agenda-app/src/lib/notices.ts.
enum NoticeHelpers {
    /// `notices` moet nieuwste-eerst gesorteerd zijn (zoals NoticeRepository.fetchNotices doet).
    static func hasUnread(_ notices: [Notice], lastSeen: Date?) -> Bool {
        guard let latest = notices.first else { return false }
        guard let lastSeen else { return true }
        return latest.created > lastSeen
    }

    static func relativeTime(_ date: Date, now: Date = Date()) -> String {
        let diffMin = max(0, Int((now.timeIntervalSince(date) / 60).rounded()))
        if diffMin < 1 { return "zojuist" }
        if diffMin < 60 { return "\(diffMin) min geleden" }
        let diffHr = Int((Double(diffMin) / 60).rounded())
        if diffHr < 24 { return "\(diffHr) uur geleden" }
        let diffDay = Int((Double(diffHr) / 24).rounded())
        if diffDay == 1 { return "gisteren" }
        if diffDay < 7 { return "\(diffDay) dagen geleden" }
        let formatter = DateFormatter()
        formatter.dateFormat = "d-M-yyyy"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }
}
