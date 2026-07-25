import Foundation

/// Toegewezenen horen ALTIJD ook in viewers (valkuil C) — volgorde-stabiele union
/// zoals Array.from(new Set([...])) in de RN-app.
enum EventViewers {
    static func union(_ viewers: [String], assignees: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for id in viewers + assignees where seen.insert(id).inserted {
            result.append(id)
        }
        return result
    }
}
