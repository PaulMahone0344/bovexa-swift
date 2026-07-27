import Foundation

/// Splitst de bedrijfslijst in wat nog moet en wat klaar is. Afgevinkte taken bleven
/// eerst op hun plek staan tussen de openstaande, waardoor je in een lange lijst moest
/// zoeken naar wat er nog te doen was.
enum TeamTaskGrouping {
    static func split(_ tasks: [AgendaTask]) -> (open: [AgendaTask], done: [AgendaTask]) {
        let open = tasks.filter { $0.status != .klaar }
        // Laatst afgevinkt bovenaan; zonder tijdstip (taken van vóór completed_at)
        // naar onderen.
        let done = tasks.filter { $0.status == .klaar }.sorted { left, right in
            switch (left.completedAt, right.completedAt) {
            case let (l?, r?): return l > r
            case (_?, nil): return true
            case (nil, _?): return false
            case (nil, nil): return left.created > right.created
            }
        }
        return (open, done)
    }
}
