import Foundation

/// Iemand met een account waarmee je gekoppeld bent. Binnen één bedrijf zie je
/// elkaar sowieso, maar afspraken naar elkaar sturen mag alleen na een koppeling:
/// zo bepaalt iedereen zelf wie er in zijn agenda mag prikken.
struct Vriend: Codable, Identifiable, Equatable {
    let id: String
    let userId: String
    let naam: String
    let email: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case naam
        case email
    }
}

/// Een uitnodiging die nog open staat. `richting` zegt of jij hem gestuurd hebt
/// of hem juist moet beantwoorden — dezelfde route levert beide, want de
/// ontvanger heeft er een knop bij en de verzender alleen een stand.
struct VriendVerzoek: Codable, Identifiable, Equatable {
    enum Richting: String, Codable {
        case inkomend
        case uitgaand
    }

    let id: String
    let naam: String
    let email: String
    let richting: Richting
    let aangemaakt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case naam
        case email
        case richting
        case aangemaakt = "created"
    }
}

/// Antwoord van `/api/agenda/friends/list`: de koppelingen en de losse verzoeken
/// in één keer, zodat het scherm met één aanroep compleet is.
struct VriendenResponse: Codable {
    let vrienden: [Vriend]
    let verzoeken: [VriendVerzoek]
}
