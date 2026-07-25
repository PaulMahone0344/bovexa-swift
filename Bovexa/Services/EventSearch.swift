import Foundation

/// Zoekscherm-filter — geport uit de resultaten-berekening in
/// ~/Desktop/agenda-app/src/app/zoek.tsx. Lege query levert bewust geen resultaten op.
enum EventSearch {
    static func search(_ events: [AgendaEvent], query: String) -> [AgendaEvent] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return [] }
        return events
            .filter { event in
                [event.title, event.location, event.notes]
                    .compactMap { $0 }
                    .contains { $0.lowercased().contains(q) }
            }
            .sorted { $0.start > $1.start }
    }
}
