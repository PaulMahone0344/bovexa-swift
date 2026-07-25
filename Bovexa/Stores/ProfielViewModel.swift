import Foundation

/// Laadt de Profiel-tab: begroeting ("Je hebt vandaag n afspraken"), de
/// meldingen-teller/-stip (valkuil D/E-voorbereiding — de meldingen zelf komen
/// in sessie B) en de lokale iPhone Agenda-sync-schakelaar (valkuil H).
@MainActor
final class ProfielViewModel: ObservableObject {
    @Published private(set) var todayCount: Int?
    @Published private(set) var pendingCount = 0
    @Published private(set) var deviceSyncEnabled: Bool

    private let repository: EventRepository
    private let now: () -> Date
    private let defaults: UserDefaults

    init(
        repository: EventRepository = EventRepository(),
        now: @escaping () -> Date = Date.init,
        defaults: UserDefaults = .standard
    ) {
        self.repository = repository
        self.now = now
        self.defaults = defaults
        self.deviceSyncEnabled = DeviceCalendarSyncPreference.isEnabled(defaults: defaults)
    }

    /// Ongelezen-stip op de Meldingen-rij. Tot sessie B de echte mededelingen
    /// ophaalt, staat deze puur op openstaande toewijzingen — geen onterecht
    /// "gelezen" laten lijken zolang dat er nog is.
    var showUnreadDot: Bool { pendingCount > 0 }

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
    }
}
