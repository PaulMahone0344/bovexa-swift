import Foundation

/// Laadt en berekent alles voor het Vandaag-scherm. Verversen gebeurt bij
/// scherm-focus (.onAppear), niet realtime.
@MainActor
final class VandaagViewModel: ObservableObject {
    @Published private(set) var isLoading = false
    @Published private(set) var hasLoadedOnce = false
    @Published private(set) var todayEvents: [AgendaEvent] = []
    @Published private(set) var nextEvent: AgendaEvent?
    @Published private(set) var appointmentCount = 0
    /// Bijregel bij het afspraken-cijfer als er hele-dag-blokken zijn.
    @Published private(set) var awayNote: String?
    @Published private(set) var plannedHoursText = "0 uur"
    @Published private(set) var weekBusyCounts: [Int] = Array(repeating: 0, count: 7)
    @Published private(set) var orgLogoURL: URL?
    /// Dagtaken die nog openstaan, voor de kaart onder de tijdlijn. Lokaal
    /// opgeslagen (UserDefaults), dus geen netwerkverzoek — wel opnieuw inlezen
    /// bij elke focus, want op de Dagtaken-tab kan er intussen iets afgevinkt zijn.
    @Published private(set) var openTasks: [PlanningNote] = []
    /// Aan als de laatste fetch mislukte. De vorige gegevens blijven dan staan —
    /// een agenda die net nog vol stond hoort na een tabwissel zonder bereik niet
    /// leeg te zijn. De view zet er één regel bij (LoadFailedNote).
    @Published private(set) var loadFailed = false


    let memberColors: MemberColors
    let labelStore: LabelStore

    private let repository: EventRepository
    private let labelRepository: LabelRepository
    private let externalCalendarService: ExternalCalendarService
    private let planningStore: PlanningNoteStore
    private let defaults: UserDefaults
    private let now: () -> Date
    /// Laatst geladen set, om bij een mislukte fetch niet terug te vallen op leeg.
    private var lastEvents: [AgendaEvent] = []

    init(
        repository: EventRepository = EventRepository(), memberColors: MemberColors = MemberColors(),
        labelRepository: LabelRepository = LabelRepository(), labelStore: LabelStore = LabelStore(),
        externalCalendarService: ExternalCalendarService = ExternalCalendarService(),
        planningStore: PlanningNoteStore = PlanningNoteStore(),
        now: @escaping () -> Date = Date.init, defaults: UserDefaults = .standard
    ) {
        self.repository = repository
        self.memberColors = memberColors
        self.labelRepository = labelRepository
        self.labelStore = labelStore
        self.externalCalendarService = externalCalendarService
        self.planningStore = planningStore
        self.now = now
        self.defaults = defaults
    }

    /// Alleen de taken die nog te doen zijn: afgevinkt en gearchiveerd horen op
    /// Vandaag niet thuis — dit is een lijstje "nog doen", geen overzicht.
    func reloadOpenTasks(userId: String) {
        planningStore.reload(userId: userId)
        openTasks = planningStore.notes.filter { !$0.done && !$0.archived }
    }

    func load(userId: String, orgId: String?, token: String) async {
        reloadOpenTasks(userId: userId)
        isLoading = true
        defer {
            isLoading = false
            hasLoadedOnce = true
        }

        async let eventsResult = try? repository.fetchAllEvents(userId: userId, orgId: orgId, token: token)
        async let membersResult = repository.listMembers(token: token)
        async let externalResult = externalCalendarService.events(
            in: ExternalCalendarMerge.fetchInterval(around: now()),
            calendarIds: ExternalCalendarSelectionPreference.selectedIds(defaults: defaults)
        )

        let events: [AgendaEvent]
        if let fetched = await eventsResult {
            events = fetched
            lastEvents = fetched
            loadFailed = false
        } else {
            // Vorige set laten staan in plaats van een lege dag tonen.
            events = lastEvents
            loadFailed = true
        }
        if let members = await membersResult {
            memberColors.prime(members: members.items, org: members.org)
            orgLogoURL = Self.logoURL(for: members.org)
        } else {
            orgLogoURL = nil
        }
        if let orgId, let labels = try? await labelRepository.fetchLabels(orgId: orgId, token: token) {
            labelStore.prime(labels: labels)
        }

        /// Valkuil E: externe events zijn zichtbaar in Vandaag (today/next), maar
        /// tellen niet mee in de tellingen over eigen werk (aantal/uren/drukte-balk).
        let ownToday = EventHelpers.eventsOnDay(events, day: now()).sorted { $0.start < $1.start }
        let combined = ExternalCalendarMerge.merge(events, external: await externalResult)
        let today = EventHelpers.eventsOnDay(combined, day: now()).sorted { $0.start < $1.start }
        todayEvents = today
        nextEvent = EventHelpers.nextUpcoming(today, now: now())
        // Besluit 26 juli: externe afspraken tellen wél mee in aantal, uren en de
        // weekstaafjes. Die cijfers gaan over hoe vol je dag is, en een vergadering
        // uit een andere agenda vult die net zo goed — anders zie je drie dingen
        // staan terwijl de teller er twee meldt.
        appointmentCount = VandaagStats.timedCount(today)
        plannedHoursText = VandaagStats.formatHours(VandaagStats.plannedHours(today))
        weekBusyCounts = VandaagStats.weekBusyCounts(combined, referenceDate: now())
        // Afwezigheid blijft over eigen werk gaan: een externe agenda kent geen
        // categorie `afwezig` en kan hier dus niets aan toevoegen.
        awayNote = VandaagStats.awayNote(ownToday)
    }

    private static func logoURL(for org: CompanyOrgInfo?) -> URL? {
        guard let org, !org.logo.isEmpty else { return nil }
        return URL(string: "\(PBEndpoint.base.absoluteString)/api/files/agenda_orgs/\(org.id)/\(org.logo)")
    }
}
