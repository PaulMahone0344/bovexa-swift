import Foundation

struct DaySheetTarget: Identifiable, Equatable {
    let day: Date
    var id: TimeInterval { day.timeIntervalSince1970 }
}

/// Alle toestand voor de Agenda-tab: weergavekeuze, geladen events, welke maand/dag
/// getoond wordt. Verversen gebeurt bij scherm-focus, niet realtime.
@MainActor
final class AgendaViewModel: ObservableObject {
    @Published private(set) var viewKind: AgendaViewKind
    @Published private(set) var events: [AgendaEvent] = []
    @Published private(set) var isLoading = false
    @Published var displayedMonth: Date
    @Published var daySheetTarget: DaySheetTarget?
    @Published var dayViewFocusDate: Date

    let memberColors: MemberColors

    private let repository: EventRepository
    private let preference: AgendaViewPreference
    private let now: () -> Date

    init(
        repository: EventRepository = EventRepository(),
        memberColors: MemberColors = MemberColors(),
        preference: AgendaViewPreference = AgendaViewPreference(),
        now: @escaping () -> Date = Date.init
    ) {
        self.repository = repository
        self.memberColors = memberColors
        self.preference = preference
        self.now = now
        let today = now()
        viewKind = preference.load()
        displayedMonth = today
        dayViewFocusDate = today
    }

    func setViewKind(_ kind: AgendaViewKind) {
        viewKind = kind
        preference.save(kind)
    }

    func load(userId: String, orgId: String?, token: String) async {
        isLoading = true
        defer { isLoading = false }

        async let eventsResult = try? repository.fetchAllEvents(userId: userId, orgId: orgId, token: token)
        async let membersResult = repository.listMembers(token: token)

        events = await eventsResult ?? []
        if let members = await membersResult {
            memberColors.prime(members: members.items)
        }
    }

    func openDaySheet(_ day: Date) {
        daySheetTarget = DaySheetTarget(day: day)
    }

    func closeDaySheet() {
        daySheetTarget = nil
    }

    func openDayView(_ day: Date) {
        dayViewFocusDate = day
        daySheetTarget = nil
        setViewKind(.dag)
    }

    /// "‹ maand"-pill: terug naar de maandweergave die actief was vóór het openen
    /// van de dagweergave (dagweergave zelf is nooit opgeslagen).
    func backToMonth() {
        displayedMonth = dayViewFocusDate
        setViewKind(preference.load())
    }

    func goToPreviousMonth(calendar: Calendar = .current) {
        displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
    }

    func goToNextMonth(calendar: Calendar = .current) {
        displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
    }

    func eventsOnDay(_ day: Date, calendar: Calendar = .current) -> [AgendaEvent] {
        EventHelpers.eventsOnDay(events, day: day, calendar: calendar)
    }
}
