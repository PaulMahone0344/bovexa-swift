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

    private let repository: EventRepository
    private let noticeRepository: NoticeRepository
    private let seenStore: NoticesSeenStore
    private let now: () -> Date
    private let defaults: UserDefaults

    init(
        repository: EventRepository = EventRepository(),
        noticeRepository: NoticeRepository = NoticeRepository(),
        seenStore: NoticesSeenStore = NoticesSeenStore(),
        now: @escaping () -> Date = Date.init,
        defaults: UserDefaults = .standard
    ) {
        self.repository = repository
        self.noticeRepository = noticeRepository
        self.seenStore = seenStore
        self.now = now
        self.defaults = defaults
        self.deviceSyncEnabled = DeviceCalendarSyncPreference.isEnabled(defaults: defaults)
    }

    /// Ongelezen-stip op de Meldingen-rij: openstaande toewijzingen (teller telt
    /// al mee) of een mededeling die je nog niet hebt gezien. Zelfde `dot={unread
    /// || pendingCount > 0}` als profiel.tsx.
    var showUnreadDot: Bool { pendingCount > 0 || unreadNotice }

    var greetingSubtitle: String {
        guard let todayCount else { return "Fijn dat je er weer bent." }
        if todayCount == 0 { return "Geen afspraken vandaag — rustige dag." }
        return "Je hebt vandaag \(todayCount) afspra\(todayCount == 1 ? "ak" : "ken")."
    }

    func setDeviceSync(_ enabled: Bool) {
        deviceSyncEnabled = enabled
        DeviceCalendarSyncPreference.setEnabled(enabled, defaults: defaults)
    }

    func load(userId: String, orgId: String?, token: String) async {
        do {
            let events = try await repository.fetchAllEvents(userId: userId, orgId: orgId, token: token)
            todayCount = EventHelpers.eventsOnDay(events, day: now()).count
            pendingCount = AssignmentHelpers.pendingCount(events, userId: userId)
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
