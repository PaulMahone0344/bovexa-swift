import Foundation

/// Haalt de agenda op voor het overzicht van één collega. Eigen viewmodel en niet
/// dat van Mensen erbij: het overzicht is een sheet die los moet kunnen laden, en
/// de afspraken van collega's zijn nergens anders in Mensen nodig.
@MainActor
final class MedewerkerDetailViewModel: ObservableObject {
    @Published private(set) var dagen: [MedewerkerInzet.Dag] = []
    @Published private(set) var afwezig: [MedewerkerInzet.Afwezig] = []
    @Published private(set) var loading = true
    /// Aan als de fetch mislukte. Zonder dit zou een netwerkfout eruitzien als
    /// "deze collega heeft nooit iets gedaan".
    @Published private(set) var loadFailed = false

    private let repository: EventRepository
    private let now: () -> Date

    init(repository: EventRepository = EventRepository(), now: @escaping () -> Date = Date.init) {
        self.repository = repository
        self.now = now
    }

    var gewerktMinuten: Int { MedewerkerInzet.minuten(dagen, geweest: true) }
    var geplandMinuten: Int { MedewerkerInzet.minuten(dagen, geweest: false) }
    var gewerkteDagen: Int { MedewerkerInzet.aantalDagen(dagen, geweest: true) }
    var geplandeDagen: Int { MedewerkerInzet.aantalDagen(dagen, geweest: false) }
    var afwezigeDagen: Int { MedewerkerInzet.afwezigeDagen(afwezig) }
    var redenen: [(reden: String, aantal: Int)] { MedewerkerInzet.perReden(afwezig) }

    /// `userId` is de ingelogde gebruiker (nodig om de agenda op te halen),
    /// `medewerkerId` degene wiens overzicht we tonen.
    func load(medewerkerId: String, userId: String, orgId: String?, token: String) async {
        loading = true
        if let events = try? await repository.fetchAllEvents(userId: userId, orgId: orgId, token: token) {
            let overzicht = MedewerkerInzet.overzicht(events: events, userId: medewerkerId, now: now())
            dagen = overzicht.dagen
            afwezig = overzicht.afwezig
            loadFailed = false
        } else {
            loadFailed = true
        }
        loading = false
    }
}
