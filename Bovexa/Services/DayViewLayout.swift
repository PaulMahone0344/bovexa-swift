import Foundation

struct PositionedEvent: Equatable {
    let event: AgendaEvent
    let column: Int
    let columnCount: Int
}

/// Verdeelt overlappende afspraken van één dag over kolommen zodat ze naast elkaar
/// staan in het uurgrid, in plaats van over elkaar heen.
enum DayViewLayout {
    static func layout(_ events: [AgendaEvent]) -> [PositionedEvent] {
        let timed = events.filter { !$0.allDay }.sorted { $0.start < $1.start }

        var result: [PositionedEvent] = []
        var cluster: [AgendaEvent] = []
        var clusterEnd: Date?

        func flush() {
            guard !cluster.isEmpty else { return }
            result.append(contentsOf: assignColumns(cluster))
            cluster = []
            clusterEnd = nil
        }

        for event in timed {
            if let end = clusterEnd, event.start < end {
                cluster.append(event)
                clusterEnd = max(end, event.end ?? event.start)
            } else {
                flush()
                cluster = [event]
                clusterEnd = event.end ?? event.start
            }
        }
        flush()

        return result
    }

    private static func assignColumns(_ cluster: [AgendaEvent]) -> [PositionedEvent] {
        var columnEnds: [Date] = []
        var assignments: [(AgendaEvent, Int)] = []

        for event in cluster {
            var placedColumn: Int?
            for (index, end) in columnEnds.enumerated() where event.start >= end {
                placedColumn = index
                break
            }
            let column = placedColumn ?? columnEnds.count
            let end = event.end ?? event.start
            if column == columnEnds.count {
                columnEnds.append(end)
            } else {
                columnEnds[column] = end
            }
            assignments.append((event, column))
        }

        let columnCount = columnEnds.count
        return assignments.map { PositionedEvent(event: $0.0, column: $0.1, columnCount: columnCount) }
    }
}
