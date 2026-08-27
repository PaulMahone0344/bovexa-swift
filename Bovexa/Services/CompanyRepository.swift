import Foundation

/// Nederlandse foutteksten voor de company/team-routes. De server stuurt meestal al
/// een leesbare Nederlandse boodschap (zie agenda_company.pb.js) — die geven we door;
/// alleen bij een lege/onleesbare fout valt dit terug op een route-specifieke tekst.
enum CompanyError: Error, Equatable {
    case message(String)

    var message: String {
        switch self {
        case .message(let text): return text
        }
    }
}

/// Datalaag voor bedrijf + team: alles via `/api/agenda/company/*` (valkuil A) — nooit
/// rechtstreeks naar `agenda_orgs`/`agenda_members`, want de PB-regels laten alleen de
/// eigenaar direct bij de org.
final class CompanyRepository {
    private let client: PBClient

    init(client: PBClient = PBClient()) {
        self.client = client
    }

    func createCompany(name: String, token: String) async throws -> CompanyInfo {
        try await run(fallback: "Bedrijf aanmaken mislukt. Probeer opnieuw.") {
            try await self.client.postCustom(CompanyInfo.self, path: "/api/agenda/company/create", body: ["name": name], token: token)
        }
    }

    func joinCompany(code: String, token: String) async throws -> CompanyInfo {
        try await run(fallback: "Toetreden mislukt. Klopt de code?") {
            try await self.client.postCustom(CompanyInfo.self, path: "/api/agenda/company/join", body: ["code": code], token: token)
        }
    }

    /// Aanvraag om aan een bedrijf gekoppeld te worden. Een nieuw account mag zelf
    /// geen bedrijf meer starten (besluit 25 augustus): het vraagt koppeling aan en
    /// de beheerder zet het door. Deze route bestaat nog niet op de server — zie
    /// MEERDERE-BEDRIJVEN-SERVER.txt; tot die tijd mislukt hij met een nette tekst
    /// en blijft de bedrijfscode de werkende weg naar binnen.
    func requestCompanyLink(companyName: String, note: String, token: String) async throws -> CompanyLinkRequest {
        try await run(fallback: "Aanvraag versturen mislukt. Probeer het later opnieuw.") {
            try await self.client.postCustom(
                CompanyLinkRequest.self, path: "/api/agenda/company/request",
                body: ["companyName": companyName, "note": note], token: token
            )
        }
    }

    /// Bedrijven waar dit account lid van is. Deze route bestaat nog niet op de
    /// server (zie MEERDERE-BEDRIJVEN-SERVER.txt); tot die tijd faalt hij en valt
    /// de app terug op het actieve bedrijf plus wat er lokaal onthouden is.
    func listMyOrgs(token: String) async throws -> MyOrgsResponse {
        try await run(fallback: "Bedrijven ophalen mislukt.") {
            try await self.client.postCustom(MyOrgsResponse.self, path: "/api/agenda/company/mine", token: token)
        }
    }

    /// Maakt een ander bedrijf actief. Antwoord is het bijgewerkte account, zodat
    /// de app daarna alles op de nieuwe `default_org` kan herladen.
    func switchOrg(orgId: String, token: String) async throws -> AgendaUser {
        try await run(fallback: "Wisselen van bedrijf mislukt.") {
            try await self.client.postCustom(AgendaUser.self, path: "/api/agenda/company/switch", body: ["orgId": orgId], token: token)
        }
    }

    func listMembers(token: String) async throws -> CompanyMembersResponse {
        try await run(fallback: "Leden ophalen mislukt.") {
            try await self.client.postCustom(CompanyMembersResponse.self, path: "/api/agenda/company/members", token: token)
        }
    }

    func setMemberRole(memberId: String, role: CompanyRole, token: String) async throws -> RoleUpdateResponse {
        try await run(fallback: "Rol wijzigen mislukt.") {
            try await self.client.postCustom(RoleUpdateResponse.self, path: "/api/agenda/company/member/role", body: ["memberId": memberId, "role": role.rawValue], token: token)
        }
    }

    func setMemberPermissions(memberId: String, key: String, value: Bool, token: String) async throws -> PermissionsUpdateResponse {
        try await run(fallback: "Rechten wijzigen mislukt.") {
            try await self.client.postCustom(PermissionsUpdateResponse.self, path: "/api/agenda/company/member/permissions", body: ["memberId": memberId, key: value], token: token)
        }
    }

    func removeMember(memberId: String, token: String) async throws -> RemoveMemberResponse {
        try await run(fallback: "Lid verwijderen mislukt.") {
            try await self.client.postCustom(RemoveMemberResponse.self, path: "/api/agenda/company/member/remove", body: ["memberId": memberId], token: token)
        }
    }

    func rotateCode(token: String) async throws -> RotateCodeResponse {
        try await run(fallback: "Code roteren mislukt.") {
            try await self.client.postCustom(RotateCodeResponse.self, path: "/api/agenda/company/code/rotate", token: token)
        }
    }

    func updateProfile(_ update: CompanyProfileUpdate, token: String) async throws -> CompanyProfileResponse {
        try await run(fallback: "Bedrijfsprofiel opslaan mislukt.") {
            try await self.client.postCustom(CompanyProfileResponse.self, path: "/api/agenda/company/profile", body: Self.profileBody(update), token: token)
        }
    }

    func sendInvite(email: String, token: String) async throws -> InviteResponse {
        try await run(fallback: "Uitnodiging versturen mislukt.") {
            try await self.client.postCustom(InviteResponse.self, path: "/api/agenda/company/invite", body: ["email": email], token: token)
        }
    }

    func uploadLogo(fileName: String, mimeType: String, fileData: Data, token: String) async throws -> LogoResponse {
        try await run(fallback: "Logo uploaden mislukt.") {
            try await self.client.postMultipart(LogoResponse.self, path: "/api/agenda/company/logo", fieldName: "logo", fileName: fileName, mimeType: mimeType, fileData: fileData, token: token)
        }
    }

    func removeLogo(token: String) async throws -> LogoResponse {
        try await run(fallback: "Logo verwijderen mislukt.") {
            try await self.client.postCustom(LogoResponse.self, path: "/api/agenda/company/logo", body: ["remove": true], token: token)
        }
    }

    private static func profileBody(_ update: CompanyProfileUpdate) -> [String: Any] {
        var body: [String: Any] = [:]
        if let address = update.address { body["address"] = address }
        if let phone = update.phone { body["phone"] = phone }
        if let email = update.email { body["email"] = email }
        if let timezone = update.timezone { body["timezone"] = timezone }
        if let defaultDurationMin = update.defaultDurationMin { body["default_duration_min"] = defaultDurationMin }
        if let openingHours = update.openingHours, let encoded = try? JSONEncoder().encode(openingHours),
           let object = try? JSONSerialization.jsonObject(with: encoded) {
            body["opening_hours"] = object
        }
        return body
    }

    private func run<T>(fallback: String, _ operation: () async throws -> T) async throws -> T {
        do {
            return try await operation()
        } catch let error as PBError {
            throw Self.translate(error, fallback: fallback)
        } catch {
            throw CompanyError.message(fallback)
        }
    }

    private static func translate(_ error: PBError, fallback: String) -> CompanyError {
        switch error {
        case .network:
            return .message("Geen verbinding. Controleer je internet en probeer opnieuw.")
        case .server(_, let message):
            return .message(message.isEmpty ? fallback : message)
        case .decoding:
            return .message(fallback)
        }
    }
}
