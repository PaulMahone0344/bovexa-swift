struct AgendaUser: Codable, Equatable {
    let id: String
    let email: String
    let naam: String?
    let avatar: String?
    private let defaultOrgRaw: String?

    enum CodingKeys: String, CodingKey {
        case id, email, naam, avatar
        case defaultOrgRaw = "default_org"
    }

    /// Lege string (PB-default voor een ongezet tekstveld) telt als "geen bedrijf".
    var defaultOrg: String? {
        guard let raw = defaultOrgRaw, !raw.isEmpty else { return nil }
        return raw
    }
}

struct AuthResponse: Decodable {
    let token: String
    let record: AgendaUser
}
