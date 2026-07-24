/// Titel-chip-verdichting voor de "Details"-maandweergave: max N chips + overflow-telling.
enum MonthDensity {
    static func titleChips(for events: [AgendaEvent], max: Int) -> (shown: [AgendaEvent], overflow: Int) {
        guard events.count > max else { return (events, 0) }
        return (Array(events.prefix(max)), events.count - max)
    }
}
