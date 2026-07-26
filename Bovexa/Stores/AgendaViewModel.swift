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
    /// Alleen de eigen afspraken, zonder de externe erbij — nodig om bij het
    /// bladeren opnieuw te kunnen samenvoegen zonder de server te bevragen.
    private var ownEvents: [AgendaEvent] = []
    @Published private(set) var isLoading = false
    @Published private(set) var hasLoadedOnce = false
    @Published var displayedMonth: Date
    /// Wiens agenda's het raster laat zien. Je eigen agenda zit er altijd in en is
    /// niet uit te vinken (besluit 26 juli): de Agenda begint bij jouw dag, en
    /// collega's vink je erbij. Zo open je de app nooit op het raster van twaalf man.
    @Published private(set) var selectedPeople: Set<String> = []
    /// Bewust niet bewaard tussen sessies: elke start begint weer bij jezelf,
    /// anders kijk je zonder het te merken nog naar de agenda van gisteren-erbij.
    private var currentUserId = ""
    /// Of de kiezer mag verschijnen — hangt aan mag_agenda_anderen_zien, dat al
    /// meekomt in de ledenlijst die deze view toch al ophaalt.
    @Published private(set) var canSeeOthersAgenda = false
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
        currentUserId = userId
        selectedPeople.insert(userId)
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

        ownEvents = await eventsResult ?? []
        events = ExternalCalendarMerge.merge(ownEvents, external: await externalResult)
        if let members = await membersResult {
            memberColors.prime(members: members.items, org: members.org)
            canSeeOthersAgenda = AgendaPersonFilterAccess.isAllowed(userId: userId, members: members.items)
            // Recht ingetrokken terwijl er nog collega's aangevinkt stonden: terug
            // naar alleen jezelf, anders blijf je naar agenda's kijken die je niet
            // meer mag opvragen.
            if !canSeeOthersAgenda { showOnlyOwnAgenda() }
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

    /// De externe agenda wordt maar één maand vóór en ná de getoonde maand opgehaald
    /// (valkuil G). Blader je verder, dan moet dat venster mee — anders zie je je
    /// eigen afspraken wél en die uit de externe agenda niet, zonder dat iets
    /// uitlegt waarom. De eigen afspraken zijn al volledig geladen en worden hier
    /// niet opnieuw opgehaald.
    func refreshExternalForDisplayedMonth() async {
        let external = await externalCalendarService.events(
            in: ExternalCalendarMerge.fetchInterval(around: displayedMonth),
            calendarIds: ExternalCalendarSelectionPreference.selectedIds(defaults: defaults)
        )
        events = ExternalCalendarMerge.merge(ownEvents, external: external)
    }

    func goToPreviousMonth(calendar: Calendar = .current) {
        displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
    }

    func goToNextMonth(calendar: Calendar = .current) {
        displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
    }

    /// Alles wat het huidige personenfilter doorlaat (m10). `events` blijft de
    /// volledige set, zodat het filter alleen de weergave raakt en niet opnieuw
    /// geladen hoeft te worden als je van persoon wisselt.
    var visibleEvents: [AgendaEvent] {
        AgendaPersonFilter.apply(events, userIds: selectedPeople)
    }

    func eventsOnDay(_ day: Date, calendar: Calendar = .current) -> [AgendaEvent] {
        EventHelpers.eventsOnDay(visibleEvents, day: day, calendar: calendar)
    }

    /// De collega's die je er zelf bij hebt gezet — jezelf dus niet. Bepaalt of de
    /// chip verschijnt die vertelt dat je meer ziet dan je eigen dag.
    var extraPeople: Set<String> {
        selectedPeople.subtracting([currentUserId])
    }

    /// Jezelf uitvinken kan niet: de Agenda begint bij jouw dag. Zonder die regel
    /// kun je alles uitzetten en naar een leeg raster kijken zonder te weten waarom.
    func togglePerson(_ userId: String) {
        guard userId != currentUserId else { return }
        if selectedPeople.contains(userId) {
            selectedPeople.remove(userId)
        } else {
            selectedPeople.insert(userId)
        }
    }

    func showEveryone() {
        selectedPeople = Set(memberColors.members.map(\.userId)).union([currentUserId])
    }

    func showOnlyOwnAgenda() {
        selectedPeople = [currentUserId]
    }
}
