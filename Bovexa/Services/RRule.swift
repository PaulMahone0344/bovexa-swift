import Foundation

/// Minimale RRULE-parser: alleen FREQ=WEEKLY met BYDAY en evt. UNTIL komt voor
/// in agenda_events.recurrence (zie SWIFT-PLAN.txt valkuil A).
struct ParsedRRule {
    let freq: String
    let byDay: [String]
    let until: Date?
}

enum RRule {
    static let weekdayNumbers: [String: Int] = ["SU": 0, "MO": 1, "TU": 2, "WE": 3, "TH": 4, "FR": 5, "SA": 6]

    static func parse(_ rule: String) -> ParsedRRule? {
        guard !rule.isEmpty else { return nil }

        var parts: [String: String] = [:]
        for rawPart in rule.split(separator: ";") {
            let kv = rawPart.split(separator: "=", maxSplits: 1)
            guard kv.count == 2 else { continue }
            parts[kv[0].trimmingCharacters(in: .whitespaces).uppercased()] = kv[1].trimmingCharacters(in: .whitespaces).uppercased()
        }

        guard let freq = parts["FREQ"] else { return nil }
        let byDay = (parts["BYDAY"] ?? "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { weekdayNumbers[$0] != nil }
        let until = parts["UNTIL"].flatMap(parseCompactDate)

        return ParsedRRule(freq: freq, byDay: byDay, until: until)
    }

    private static func parseCompactDate(_ value: String) -> Date? {
        let compact = value.replacingOccurrences(of: "-", with: "")
        guard compact.count == 8, compact.allSatisfy(\.isNumber) else { return nil }

        var comps = DateComponents()
        comps.year = Int(compact.prefix(4))
        comps.month = Int(compact.dropFirst(4).prefix(2))
        comps.day = Int(compact.dropFirst(6).prefix(2))
        comps.hour = 0
        comps.minute = 0
        comps.second = 0

        return Calendar(identifier: .gregorian).date(from: comps)
    }
}
