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
    @Published private(set) var plannedHoursText = "0 uur"
    @Published private(set) var weekBusyCounts: [Int] = Array(repeating: 0, count: 7)
    @Published private(set) var orgLogoURL: URL?

    let memberColors: MemberColors

    private let repository: EventRepository
    private let now: () -> Date

    init(repository: EventRepository = EventRepository(), memberColors: MemberColors = MemberColors(), now: @escaping () -> Date = Date.init) {
        self.repository = repository
        self.memberColors = memberColors
        self.now = now
    }

    func load(userId: String, orgId: String?, token: String) async {
        isLoading = true
        defer {
            isLoading = false
            hasLoadedOnce = true
        }

        async let eventsResult = try? repository.fetchAllEvents(userId: userId, orgId: orgId, token: token)
        async let membersResult = repository.listMembers(token: token)

        let events = await eventsResult ?? []
        if let members = await membersResult {
            memberColors.prime(members: members.items)
            orgLogoURL = Self.logoURL(for: members.org)
        } else {
            orgLogoURL = nil
        }

        let today = EventHelpers.eventsOnDay(events, day: now()).sorted { $0.start < $1.start }
        todayEvents = today
        nextEvent = EventHelpers.nextUpcoming(today, now: now())
        appointmentCount = VandaagStats.appointmentCount(today)
        plannedHoursText = VandaagStats.formatHours(VandaagStats.plannedHours(today))
        weekBusyCounts = VandaagStats.weekBusyCounts(events, referenceDate: now())
    }

    private static func logoURL(for org: CompanyOrgInfo?) -> URL? {
        guard let org, !org.logo.isEmpty else { return nil }
        return URL(string: "\(PBEndpoint.base.absoluteString)/api/files/agenda_orgs/\(org.id)/\(org.logo)")
    }
}
