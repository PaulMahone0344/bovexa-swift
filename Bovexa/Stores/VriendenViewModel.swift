import Foundation

/// Vrienden: koppelingen tussen twee accounts. Je nodigt iemand uit op zijn
/// e-mailadres, die persoon accepteert, en pas daarna kunnen jullie elkaar
/// afspraken sturen. Binnen één bedrijf ken je elkaar al via het team; dit gaat
/// over de mensen daarbuiten, en over wie er in jouw agenda mag prikken.
@MainActor
final class VriendenViewModel: ObservableObject {
    @Published private(set) var vrienden: [Vriend] = []
    @Published private(set) var inkomend: [VriendVerzoek] = []
    @Published private(set) var uitgaand: [VriendVerzoek] = []
    @Published private(set) var loading = false
    @Published private(set) var loaded = false
    @Published var email = ""
    @Published private(set) var versturen = false
    @Published var foutmelding: String?
    @Published var bevestiging: String?
    @Published private(set) var beantwoordId: String?

    private let repository: VriendRepository
    private let token: String

    init(token: String, repository: VriendRepository = VriendRepository()) {
        self.token = token
        self.repository = repository
    }

    /// Een adres is pas bruikbaar met een @ en iets erachter; verder laten we de
    /// server oordelen, die weet of het account bestaat.
    var kanVersturen: Bool {
        let adres = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !versturen, adres.contains("@") else { return false }
        return !adres.hasPrefix("@") && !adres.hasSuffix("@")
    }

    func load() async {
        loading = !loaded
        defer {
            loading = false
            loaded = true
        }
        do {
            let response = try await repository.list(token: token)
            vrienden = response.vrienden
            inkomend = response.verzoeken.filter { $0.richting == .inkomend }
            uitgaand = response.verzoeken.filter { $0.richting == .uitgaand }
            foutmelding = nil
        } catch {
            // Eerdere lijst laten staan: een hikje mag je vrienden niet wegvegen.
            foutmelding = (error as? CompanyError)?.message ?? "Vrienden ophalen mislukt."
        }
    }

    func nodigUit() async {
        guard kanVersturen else { return }
        let adres = email.trimmingCharacters(in: .whitespacesAndNewlines)
        versturen = true
        defer { versturen = false }
        do {
            let verzoek = try await repository.invite(email: adres, token: token)
            uitgaand.append(verzoek)
            email = ""
            bevestiging = "Verzoek gestuurd naar \(adres)."
        } catch {
            foutmelding = (error as? CompanyError)?.message ?? "Verzoek versturen mislukt."
        }
    }

    func beantwoord(_ verzoek: VriendVerzoek, accepteren: Bool) async {
        guard beantwoordId == nil else { return }
        beantwoordId = verzoek.id
        defer { beantwoordId = nil }
        do {
            try await repository.respond(requestId: verzoek.id, accept: accepteren, token: token)
            inkomend.removeAll { $0.id == verzoek.id }
            // Opnieuw laden: bij accepteren komt er een vriend bij, en die naam
            // wil je meteen in de lijst zien staan.
            if accepteren { await load() }
        } catch {
            foutmelding = (error as? CompanyError)?.message ?? "Antwoorden mislukt."
        }
    }

    func verwijder(_ vriend: Vriend) async {
        do {
            try await repository.remove(vriendId: vriend.id, token: token)
            vrienden.removeAll { $0.id == vriend.id }
        } catch {
            foutmelding = (error as? CompanyError)?.message ?? "Verwijderen mislukt."
        }
    }
}
