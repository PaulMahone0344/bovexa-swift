/// Response van POST /api/agenda/company/members — alleen velden die milestone 1
/// gebruikt (persoonskleuren, voornaam-labels, logo-banner op Vandaag).
struct Member: Decodable, Equatable {
    let id: String
    let userId: String
    let naam: String
    let email: String
    let avatar: String
}

struct CompanyOrgInfo: Decodable, Equatable {
    let id: String
    let name: String
    let logo: String
}

struct MembersResponse: Decodable {
    let items: [Member]
    let org: CompanyOrgInfo?
}
