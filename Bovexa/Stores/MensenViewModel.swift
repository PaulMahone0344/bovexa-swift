import Foundation

/// Mensen-scherm (m8): privécontacten van de gebruiker naast collega's uit het
/// bedrijf. Twee losse databronnen (valkuil A) die alleen op het scherm onder
/// elkaar staan — collega's blijven hier alleen-lezen, wijzigen gebeurt bij Bedrijf.
@MainActor
final class MensenViewModel: ObservableObject {
    @Published private(set) var contacts: [AgendaContact] = []
    @Published private(set) var members: [CompanyMember] = []
    @Published private(set) var orgName: String = ""
    @Published var query: String = ""
    @Published private(set) var loading = false
    @Published var errorMessage: String?

    private let contactRepository: ContactRepository
    private let companyRepository: CompanyRepository

    init(contactRepository: ContactRepository = ContactRepository(), companyRepository: CompanyRepository = CompanyRepository()) {
        self.contactRepository = contactRepository
        self.companyRepository = companyRepository
    }

    var visibleContacts: [AgendaContact] { MensenSearchHelpers.filterContacts(contacts, query: query) }
    var visibleMembers: [CompanyMember] { MensenSearchHelpers.filterMembers(members, query: query) }

    func load(userId: String, token: String) async {
        loading = true
        defer { loading = false }
        async let contactsResult = contactRepository.fetchContacts(userId: userId, token: token)
        async let membersResult = companyRepository.listMembers(token: token)

        if let fetched = try? await contactsResult {
            contacts = fetched
        }
        if let response = try? await membersResult {
            members = response.items
            orgName = response.org?.name ?? ""
        }
    }

    func addContact(userId: String, naam: String, telefoon: String, notitie: String, token: String) async -> Bool {
        let trimmedNaam = naam.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNaam.isEmpty else {
            errorMessage = "Vul een naam in."
            return false
        }
        do {
            let contact = try await contactRepository.createContact(eigenaar: userId, naam: trimmedNaam, telefoon: telefoon, notitie: notitie, token: token)
            contacts = sorted(contacts + [contact])
            errorMessage = nil
            return true
        } catch {
            errorMessage = "Kon contact niet toevoegen."
            return false
        }
    }

    func updateContact(id: String, naam: String, telefoon: String, notitie: String, token: String) async -> Bool {
        let trimmedNaam = naam.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNaam.isEmpty else {
            errorMessage = "Vul een naam in."
            return false
        }
        do {
            let updated = try await contactRepository.updateContact(id: id, naam: trimmedNaam, telefoon: telefoon, notitie: notitie, token: token)
            contacts = sorted(contacts.map { $0.id == updated.id ? updated : $0 })
            errorMessage = nil
            return true
        } catch {
            errorMessage = "Kon contact niet wijzigen."
            return false
        }
    }

    func deleteContact(id: String, token: String) async {
        do {
            try await contactRepository.deleteContact(id: id, token: token)
            contacts = contacts.filter { $0.id != id }
        } catch {
            errorMessage = "Kon contact niet verwijderen."
        }
    }

    private func sorted(_ items: [AgendaContact]) -> [AgendaContact] {
        items.sorted { $0.naam.localizedCaseInsensitiveCompare($1.naam) == .orderedAscending }
    }
}
