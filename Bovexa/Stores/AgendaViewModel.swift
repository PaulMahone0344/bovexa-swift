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
    @Published private(set) var hasLoadedOnce = false
    @Published var displayedMonth: Date
    @Published var daySheetTarget: DaySheetTarget?
    @Published var dayViewFocusDate: Date

    let memberColors: MemberColors
    let labelStore: LabelStore

    private let repository: EventRepository
    private let labelRepository: LabelRepository
    private let preference: AgendaViewPreference
    private let externalCalendarService: ExternalCalendarService
    private let defaults: UserDefaults
    private let now: () -> Date

    init(
        repository: EventRepository = EventRepository(),
        memberColors: MemberColors = MemberColors(),
        labelRepository: LabelRepository = LabelRepository(),
        labelStore: LabelStore = LabelStore(),
        preference: AgendaViewPreference = AgendaViewPreference(),
        externalCalendarService: ExternalCalendarService = ExternalCalendarService(),
        defaults: UserDefaults = .standard,
        now: @escaping () -> Date = Date.init
    ) {
        self.repository = repository
        self.memberColors = memberColors
        self.labelRepository = labelRepository
        self.labelStore = labelStore
        self.preference = preference
        self.externalCalendarService = externalCalendarService
        self.defaults = defaults
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
        defer {
            isLoading = false
            hasLoadedOnce = true
        }

        async let eventsResult = try? repository.fetchAllEvents(userId: userId, orgId: orgId, token: token)
        async let membersResult = repository.listMembers(token: token)
        async let externalResult = externalCalendarService.events(
            in: ExternalCalendarMerge.fetchInterval(around: displayedMonth),
            calendarIds: ExternalCalendarSelectionPreference.selectedIds(defaults: defaults)
        )

        let ownEvents = await eventsResult ?? []
        events = ExternalCalendarMerge.merge(ownEvents, external: await externalResult)
        if let members = await membersResult {
            memberColors.prime(members: members.items, org: members.org)
        }
        if let orgId, let labels = try? await labelRepository.fetchLabels(orgId: orgId, token: token) {
            labelStore.prime(labels: labels)
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
