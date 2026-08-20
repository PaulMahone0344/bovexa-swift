import Foundation

/// Laadt de Profiel-tab: begroeting ("Je hebt vandaag n afspraken"), de
/// meldingen-teller/-stip (valkuil D/E-voorbereiding — de meldingen zelf komen
/// in sessie B) en de lokale iPhone Agenda-sync-schakelaar (valkuil H).
@MainActor
final class ProfielViewModel: ObservableObject {
    @Published private(set) var todayCount: Int?
    @Published private(set) var pendingCount = 0
    @Published private(set) var unreadNotice = false
    @Published private(set) var deviceSyncEnabled: Bool
    /// Agenda's van het toestel (m9 plak 3) — leeg zolang niet geladen of geweigerd.
    @Published private(set) var externalCalendars: [DeviceCalendarInfo] = []
    @Published private(set) var externalCalendarAccessDenied = false
    /// Toegang staat al aan: de lijst mag getoond worden zonder iets te vragen.
    @Published private(set) var externalCalendarAccessGranted = false
    @Published private(set) var selectedExternalCalendarIds: Set<String>

    private let repository: EventRepository
    private let noticeRepository: NoticeRepository
    private let seenStore: NoticesSeenStore
    private let externalCalendarService: ExternalCalendarService
    private let now: () -> Date
    private let defaults: UserDefaults

    init(
        repository: EventRepository = EventRepository(),
        noticeRepository: NoticeRepository = NoticeRepository(),
        seenStore: NoticesSeenStore = NoticesSeenStore(),
        externalCalendarService: ExternalCalendarService = ExternalCalendarService(),
        now: @escaping () -> Date = Date.init,
        defaults: UserDefaults = .standard
    ) {
        self.repository = repository
        self.noticeRepository = noticeRepository
        self.seenStore = seenStore
        self.externalCalendarService = externalCalendarService
        self.now = now
        self.defaults = defaults
        self.deviceSyncEnabled = DeviceCalendarSyncPreference.isEnabled(defaults: defaults)
        self.selectedExternalCalendarIds = ExternalCalendarSelectionPreference.selectedIds(defaults: defaults)
    }

    /// Ongelezen-stip op de Meldingen-rij: openstaande toewijzingen (teller telt
    /// al mee) of een mededeling die je nog niet hebt gezien. Zelfde `dot={unread
    /// || pendingCount > 0}` als profiel.tsx.
    var showUnreadDot: Bool { pendingCount > 0 || unreadNotice }

    /// Voor de tab-badge (6b): één ongelezen mededeling telt als één, want
    /// NoticeHelpers weet alleen óf er iets nieuws is, niet hoeveel.
    var unreadNoticeCount: Int { unreadNotice ? 1 : 0 }

    var greetingSubtitle: String {
        guard let todayCount else { return "Fijn dat je er weer bent." }
        if todayCount == 0 { return "Geen afspraken vandaag — rustige dag." }
        return "Je hebt vandaag \(todayCount) afspra\(todayCount == 1 ? "ak" : "ken")."
    }

    func setDeviceSync(_ enabled: Bool) {
        deviceSyncEnabled = enabled
        DeviceCalendarSyncPreference.setEnabled(enabled, defaults: defaults)
    }

    /// Bij het openen van Profiel: alleen uitlezen wat al mag. Nooit vragen — de
    /// systeemprompt voor volledige agendatoegang hoort bij een tik van de
    /// gebruiker, niet bij het openen van een tabblad.
    func loadExternalCalendarsIfAuthorized() {
        externalCalendarAccessGranted = externalCalendarService.hasFullAccess
        externalCalendars = externalCalendarService.calendarsIfAuthorized()
    }

    /// Valkuil F: geweigerde toegang geeft een lege lijst en een uitlegregel, nooit een
    /// kapot scherm. Roept de systeemprompt op, dus alleen na een expliciete tik.
    func requestExternalCalendarAccess() async {
        let result = await externalCalendarService.loadCalendars()
        externalCalendars = result.calendars
        externalCalendarAccessGranted = result.granted
        externalCalendarAccessDenied = !result.granted
    }

    func toggleExternalCalendar(_ id: String) {
        if selectedExternalCalendarIds.contains(id) {
            selectedExternalCalendarIds.remove(id)
        } else {
            selectedExternalCalendarIds.insert(id)
        }
        ExternalCalendarSelectionPreference.setSelectedIds(selectedExternalCalendarIds, defaults: defaults)
    }

    func load(userId: String, orgId: String?, token: String) async {
        do {
            let events = try await repository.fetchAllEvents(userId: userId, orgId: orgId, token: token)
            todayCount = EventHelpers.eventsOnDay(events, day: now()).count
            // now() meegeven, anders blijft de stip branden voor toewijzingen op
            // afspraken die al geweest zijn.
            pendingCount = AssignmentHelpers.pendingCount(events, userId: userId, now: now())
        } catch {
            todayCount = nil
            pendingCount = 0
        }

        guard let orgId else {
            unreadNotice = false
            return
        }
        if let notices = try? await noticeRepository.fetchNotices(orgId: orgId, token: token) {
            unreadNotice = NoticeHelpers.hasUnread(notices, lastSeen: seenStore.lastSeen(userId: userId))
        } else {
            unreadNotice = false
        }
    }
}
