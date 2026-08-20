import Foundation

/// Klanten-scherm: groepeert afspraken op klantnaam (valkuil F). Geen eigen
/// datalaag nodig buiten EventRepository.fetchAllEvents — puur afgeleide data.
@MainActor
final class KlantenViewModel: ObservableObject {
    @Published private(set) var groups: [KlantGroup] = []
    @Published private(set) var loading = true

    /// Sinds M11 plak 3e eigendom van de viewmodel in plaats van verse @StateObjects
    /// in de view: het afspraak-detail vanuit Klanten kreeg nooit-geprimede stores,
    /// dus een collega heette "collega", labelkleuren ontbraken en de editor kon
    /// niemand toewijzen. Zelfde opzet als VandaagViewModel.
    let memberColors = MemberColors()
    let labelStore = LabelStore()

    private let userId: String
    private let orgId: String?
    private let token: String
    private let repository: EventRepository
    private let labelRepository: LabelRepository

    init(
        userId: String, orgId: String?, token: String,
        repository: EventRepository = EventRepository(),
        labelRepository: LabelRepository = LabelRepository()
    ) {
        self.userId = userId
        self.orgId = orgId
        self.token = token
        self.repository = repository
        self.labelRepository = labelRepository
    }

    func load() async {
        loading = true

        async let eventsResult = try? repository.fetchAllEvents(userId: userId, orgId: orgId, token: token)
        async let membersResult = repository.listMembers(token: token)

        if let events = await eventsResult {
            groups = KlantGrouping.group(events)
        } else {
            groups = []
        }
        if let members = await membersResult {
            memberColors.prime(members: members.items, org: members.org)
        }
        // Valkuil C elders in de app: zonder bedrijf bestaan er geen labels, dus
        // ook geen netwerkverzoek.
        if let orgId, let labels = try? await labelRepository.fetchLabels(orgId: orgId, token: token) {
            labelStore.prime(labels: labels)
        }

        loading = false
    }
}
