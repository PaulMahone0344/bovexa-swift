import Foundation

/// Klanten-scherm: groepeert afspraken op klantnaam (valkuil F). Geen eigen
/// datalaag nodig buiten EventRepository.fetchAllEvents — puur afgeleide data.
@MainActor
final class KlantenViewModel: ObservableObject {
    @Published private(set) var groups: [KlantGroup] = []
    @Published private(set) var loading = true

    private let userId: String
    private let orgId: String?
    private let token: String
    private let repository: EventRepository

    init(userId: String, orgId: String?, token: String, repository: EventRepository = EventRepository()) {
        self.userId = userId
        self.orgId = orgId
        self.token = token
        self.repository = repository
    }

    func load() async {
        loading = true
        if let events = try? await repository.fetchAllEvents(userId: userId, orgId: orgId, token: token) {
            groups = KlantGrouping.group(events)
        } else {
            groups = []
        }
        loading = false
    }
}
