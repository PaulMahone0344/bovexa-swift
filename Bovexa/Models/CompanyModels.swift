import Foundation

/// Rol op `agenda_members`. `manager` bestaat in het schema (werklaag) maar is niet
/// kiesbaar in deze milestone — zie `SelectableCompanyRole`.
enum CompanyRole: String, Codable, Equatable {
    case member
    case manager
    case admin
}

/// Response van company/create en company/join.
struct CompanyInfo: Decodable, Equatable {
    let id: String
    let name: String
    let joinCode: String
    let plan: String
    let seatsMax: Int
    let role: CompanyRole

    enum CodingKeys: String, CodingKey {
        case id, name, plan, role
        case joinCode = "join_code"
        case seatsMax = "seats_max"
    }
}

/// Eén regel uit company/members — server stuurt hier al camelCase (zie agenda_company.pb.js).
struct CompanyMember: Decodable, Equatable, Identifiable {
    let id: String
    let userId: String
    let naam: String
    let email: String
    let avatar: String
    var role: CompanyRole
    let status: String
    let isOwner: Bool
    var magMaken: Bool
    var magWijzigen: Bool
    var magVerwijderen: Bool
    var magKlantZien: Bool
    var magAgendaAnderenZien: Bool

    var isInvited: Bool { status == "invited" }
    var displayName: String { naam.isEmpty ? email : naam }

    /// Valkuil C: rol/rechten wijzigen en verwijderen mag nooit op jezelf of de
    /// eigenaar. Server weigert het al; deze check zorgt dat de knoppen in de UI
    /// nooit verschijnen voor een actie die toch zou worden geweigerd.
    func canBeManaged(by actingUserId: String) -> Bool {
        !isOwner && userId != actingUserId
    }
}

/// Rollen die een admin daadwerkelijk kan kiezen (valkuil D: Manager hoort bij de
/// verborgen werklaag).
enum SelectableCompanyRole: String, CaseIterable {
    case member
    case admin

    var role: CompanyRole {
        switch self {
        case .member: return .member
        case .admin: return .admin
        }
    }

    var label: String {
        switch self {
        case .member: return "Medewerker"
        case .admin: return "Admin"
        }
    }
}

struct DayHours: Codable, Equatable {
    var open: String
    var close: String
}

struct OpeningHours: Codable, Equatable {
    var mon: DayHours?
    var tue: DayHours?
    var wed: DayHours?
    var thu: DayHours?
    var fri: DayHours?
    var sat: DayHours?
    var sun: DayHours?

    static let empty = OpeningHours()

    /// Volgorde Ma-Zo voor de openingstijden-lijst in Teambeheer.
    static let dayOrder: [(key: WritableKeyPath<OpeningHours, DayHours?>, label: String)] = [
        (\OpeningHours.mon, "Ma"),
        (\OpeningHours.tue, "Di"),
        (\OpeningHours.wed, "Wo"),
        (\OpeningHours.thu, "Do"),
        (\OpeningHours.fri, "Vr"),
        (\OpeningHours.sat, "Za"),
        (\OpeningHours.sun, "Zo"),
    ]
}

/// Bedrijfsprofiel zoals meegestuurd in het `org`-veld van company/members.
struct CompanyOrgProfile: Decodable, Equatable {
    let id: String
    let name: String
    let logo: String
    let icsToken: String
    let address: String
    let phone: String
    let email: String
    let openingHours: OpeningHours?
    let timezone: String
    let defaultDurationMin: Int

    enum CodingKeys: String, CodingKey {
        case id, name, logo, address, phone, email, timezone
        case icsToken = "ics_token"
        case openingHours = "opening_hours"
        case defaultDurationMin = "default_duration_min"
    }
}

struct CompanyMembersResponse: Decodable, Equatable {
    let items: [CompanyMember]
    let seatsMax: Int
    let plan: String
    let joinCode: String
    let org: CompanyOrgProfile?

    enum CodingKeys: String, CodingKey {
        case items, plan, org
        case seatsMax = "seats_max"
        case joinCode = "join_code"
    }
}

struct RoleUpdateResponse: Decodable, Equatable {
    let id: String
    let role: CompanyRole
}

struct PermissionsUpdateResponse: Decodable, Equatable {
    let id: String
    let magMaken: Bool
    let magWijzigen: Bool
    let magVerwijderen: Bool
    let magKlantZien: Bool
    let magAgendaAnderenZien: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case magMaken = "mag_maken"
        case magWijzigen = "mag_wijzigen"
        case magVerwijderen = "mag_verwijderen"
        case magKlantZien = "mag_klant_zien"
        case magAgendaAnderenZien = "mag_agenda_anderen_zien"
    }
}

struct RemoveMemberResponse: Decodable, Equatable {
    let id: String
    let removed: Bool
}

struct RotateCodeResponse: Decodable, Equatable {
    let joinCode: String

    enum CodingKeys: String, CodingKey {
        case joinCode = "join_code"
    }
}

struct CompanyProfileResponse: Decodable, Equatable {
    let id: String
    let address: String
    let phone: String
    let email: String
    let openingHours: OpeningHours?
    let timezone: String
    let defaultDurationMin: Int

    enum CodingKeys: String, CodingKey {
        case id, address, phone, email, timezone
        case openingHours = "opening_hours"
        case defaultDurationMin = "default_duration_min"
    }
}

struct InviteResponse: Decodable, Equatable {
    let sent: Bool
    let email: String
}

struct LogoResponse: Decodable, Equatable {
    let id: String
    let logo: String
}

/// Update-payload voor company/profile — alleen meegestuurde velden worden gewijzigd.
struct CompanyProfileUpdate {
    var address: String?
    var phone: String?
    var email: String?
    var timezone: String?
    var defaultDurationMin: Int?
    var openingHours: OpeningHours?
}
