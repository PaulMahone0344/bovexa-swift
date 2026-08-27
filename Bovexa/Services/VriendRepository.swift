import Foundation

/// Datalaag voor de vriendenkoppelingen. Alles loopt via `/api/agenda/friends/*`,
/// om dezelfde reden als bij het bedrijf: de PocketBase-regels laten een account
/// niet zomaar in de gegevens van een ander account kijken, dus de server doet de
/// controle en het versturen van de uitnodigingsmail.
///
/// Deze routes bestaan nog niet op de server — zie MEERDERE-BEDRIJVEN-SERVER.txt
/// punt 19. Tot die tijd mislukken ze met een nette Nederlandse tekst en blijft
/// het scherm leeg in plaats van dat het crasht.
final class VriendRepository {
    private let client: PBClient

    init(client: PBClient = PBClient()) {
        self.client = client
    }

    /// Koppelingen en openstaande verzoeken in één aanroep.
    func list(token: String) async throws -> VriendenResponse {
        try await run(fallback: "Vrienden ophalen mislukt.") {
            try await self.client.postCustom(VriendenResponse.self, path: "/api/agenda/friends/list", token: token)
        }
    }

    /// Uitnodiging op e-mailadres. Bestaat er een account op dat adres, dan krijgt
    /// die persoon het verzoek in de app te zien; zo niet, dan stuurt de server een
    /// mail met een uitnodiging om zich aan te melden.
    func invite(email: String, token: String) async throws -> VriendVerzoek {
        try await run(fallback: "Verzoek versturen mislukt. Klopt het e-mailadres?") {
            try await self.client.postCustom(
                VriendVerzoek.self, path: "/api/agenda/friends/invite",
                body: ["email": email], token: token
            )
        }
    }

    /// Accepteren of weigeren van een inkomend verzoek.
    func respond(requestId: String, accept: Bool, token: String) async throws {
        _ = try await run(fallback: "Antwoorden mislukt. Probeer opnieuw.") {
            try await self.client.postCustom(
                VriendVerzoek.self, path: "/api/agenda/friends/respond",
                body: ["requestId": requestId, "accept": accept], token: token
            )
        }
    }

    /// Koppeling opheffen. Werkt beide kanten op: daarna kan geen van beiden nog
    /// een afspraak naar de ander sturen.
    func remove(vriendId: String, token: String) async throws {
        _ = try await run(fallback: "Verwijderen mislukt. Probeer opnieuw.") {
            try await self.client.postCustom(
                VriendVerzoek.self, path: "/api/agenda/friends/remove",
                body: ["friendId": vriendId], token: token
            )
        }
    }

    /// Zelfde vertaalslag als CompanyRepository: de servertekst wint, anders de
    /// route-eigen tekst.
    private func run<T>(fallback: String, _ body: () async throws -> T) async throws -> T {
        do {
            return try await body()
        } catch let error as PBError {
            switch error {
            case .network:
                throw CompanyError.message("Geen verbinding. Controleer je internet en probeer opnieuw.")
            case .server(_, let message):
                throw CompanyError.message(message.isEmpty ? fallback : message)
            case .decoding:
                throw CompanyError.message(fallback)
            }
        } catch {
            throw CompanyError.message(fallback)
        }
    }
}
