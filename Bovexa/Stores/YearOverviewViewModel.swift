import Foundation

/// Viewmodel voor het jaaroverzicht: eigen fetch, jaar-navigatie, dag/maand-tellingen.
@MainActor
final class YearOverviewViewModel: ObservableObject {
    @Published var year: Int
    @Published private(set) var eventDays: Set<EventDayKey> = []

    private let repository: EventRepository

    init(repository: EventRepository = EventRepository(), now: @escaping () -> Date = Date.init) {
        self.repository = repository
        year = Calendar.current.component(.year, from: now())
    }

    func goToPreviousYear() { year -= 1 }
    func goToNextYear() { year += 1 }

    func load(userId: String, orgId: String?, token: String) async {
        let events = (try? await repository.fetchAllEvents(userId: userId, orgId: orgId, token: token)) ?? []
        eventDays = EventDaySet.build(from: events)
    }

    func dayCount(forMonth month: Int) -> Int {
        eventDays.filter { $0.year == year && $0.month == month }.count
    }

    func hasEvents(month: Int, day: Int) -> Bool {
        eventDays.contains(EventDayKey(year: year, month: month, day: day))
    }

    var totalDaysPlannedThisYear: Int {
        eventDays.filter { $0.year == year }.count
    }
}
