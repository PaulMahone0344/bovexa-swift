import Foundation

/// agenda_notices — bedrijfsmededeling. Geport uit ~/Desktop/agenda-app/src/lib/notices.ts.
struct Notice: Decodable, Identifiable, Equatable {
    let id: String
    let org: String
    let author: String
    let authorNaam: String
    let title: String?
    let body: String
    let created: Date

    enum CodingKeys: String, CodingKey {
        case id, org, author, title, body, created
        case authorNaam = "author_naam"
    }

    init(id: String, org: String, author: String, authorNaam: String, title: String?, body: String, created: Date) {
        self.id = id
        self.org = org
        self.author = author
        self.authorNaam = authorNaam
        self.title = title
        self.body = body
        self.created = created
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        org = (try? c.decode(String.self, forKey: .org)) ?? ""
        author = (try? c.decode(String.self, forKey: .author)) ?? ""
        authorNaam = (try? c.decode(String.self, forKey: .authorNaam)) ?? ""
        title = try c.decodeIfPresent(String.self, forKey: .title)
        body = (try? c.decode(String.self, forKey: .body)) ?? ""
        let createdRaw = (try? c.decode(String.self, forKey: .created)) ?? ""
        created = PBDate.parse(createdRaw) ?? Date(timeIntervalSince1970: 0)
    }
}
