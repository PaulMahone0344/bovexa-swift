import Foundation

/// Haalt de afspraken op voor het inzet-overzicht op "Persoon wijzigen". Eigen
/// viewmodel en niet die van Mensen erbij: het formulier is een sheet die ook
/// zonder de rest van dat scherm moet kunnen laden, en de afspraken zijn nergens
/// anders in Mensen nodig.
@MainActor
final class PersoonInzetViewModel: ObservableObject {
    @Published private(set) var regels: [ContactInzet.Regel] = []
    @Published private(set) var loading = true
    /// Aan als de fetch mislukte. Zonder dit zou een netwerkfout eruitzien als
    /// "deze persoon is nooit ingepland" (4l).
    @Published private(set) var loadFailed = false

    private let repository: EventRepository
    private let now: () -> Date

    init(repository: EventRepository = EventRepository(), now: @escaping () -> Date = Date.init) {
        self.repository = repository
        self.now = now
    }

    var geweestMinuten: Int { ContactInzet.minuten(regels, geweest: true) }
    var geplandMinuten: Int { ContactInzet.minuten(regels, geweest: false) }

    func load(contact: AgendaContact, userId: String, orgId: String?, token: String) async {
        loading = true
        // Een contact van een bedrijf kan afspraken van collega's hebben; een
        // privécontact niet. fetchAllEvents filtert daar zelf al op.
        let org = contact.org.isEmpty ? orgId : contact.org
        if let events = try? await repository.fetchAllEvents(userId: userId, orgId: org, token: token) {
            regels = ContactInzet.regels(events: events, contact: contact, now: now())
            loadFailed = false
        } else {
            loadFailed = true
        }
        loading = false
    }
}
