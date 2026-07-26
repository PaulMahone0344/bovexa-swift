import Foundation

/// Zoeken op het Mensen-scherm (m8): filtert privécontacten en collega's los van
/// elkaar op dezelfde zoekterm, zodat beide secties gelijktijdig meebewegen.
enum MensenSearchHelpers {
    static func filterContacts(_ contacts: [AgendaContact], query: String) -> [AgendaContact] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return contacts }
        return contacts.filter { "\($0.naam) \($0.telefoon)".lowercased().contains(q) }
    }

    static func filterMembers(_ members: [CompanyMember], query: String) -> [CompanyMember] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return members }
        return members.filter { "\($0.naam) \($0.email)".lowercased().contains(q) }
    }
}
