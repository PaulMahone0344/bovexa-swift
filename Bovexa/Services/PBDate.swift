import Foundation

/// Tolerante parser voor het PocketBase-datumformaat "yyyy-MM-dd HH:mm:ss.SSSZ" (UTC).
enum PBDate {
    private static let withMillis: DateFormatter = makeFormatter("yyyy-MM-dd HH:mm:ss.SSS'Z'")
    private static let withoutMillis: DateFormatter = makeFormatter("yyyy-MM-dd HH:mm:ss'Z'")

    private static func makeFormatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }

    static func parse(_ string: String) -> Date? {
        withMillis.date(from: string)
            ?? withoutMillis.date(from: string)
            ?? ISO8601DateFormatter().date(from: string)
    }

    /// Voor update-payloads (valkuil E): altijd UTC met milliseconden, zoals PocketBase teruggeeft.
    static func format(_ date: Date) -> String {
        withMillis.string(from: date)
    }
}
