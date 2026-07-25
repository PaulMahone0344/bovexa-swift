import Foundation

/// Dubbele-boeking-check — geport uit findOverlap() in ~/Desktop/agenda-app/src/lib/events.ts.
enum EventOverlap {
    /// Eerste eigen afspraak die overlapt met [start, end), of nil. `excludeId` = het
    /// echte record-id om jezelf over te slaan bij bewerken (valkuil A). Aansluitende
    /// afspraken (bestaand einde == nieuw begin, of omgekeerd) tellen niet als overlap.
    static func findOverlap(in events: [AgendaEvent], start: Date, end: Date, excludeId: String? = nil) -> AgendaEvent? {
        for event in events {
            if let excludeId, EventHelpers.eventRecordId(event) == excludeId { continue }
            let existingStart = event.start
            let existingEnd = event.end ?? event.start
            if start < existingEnd, end > existingStart {
                return event
            }
        }
        return nil
    }
}
