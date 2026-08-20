import Foundation

/// Beheer van de labellegenda (m7 plak 6): hernoemen/kleur wijzigen/toevoegen mag
/// iedereen in het bedrijf, verwijderen alleen admins (valkuil G) — dat raakt
/// afspraken van collega's. Rol wordt hetzelfde opgehaald als in MeldingenViewModel.
@MainActor
final class LegendeViewModel: ObservableObject {
    @Published private(set) var isAdmin = false
    @Published var actionFailedAlert = false
    /// Aan zolang er een label wordt aangemaakt (M11 plak 3h). Zonder deze guard
    /// bleef de knop actief tijdens de netwerkronde en maakte een tweede tik een
    /// tweede label met dezelfde naam.
    @Published private(set) var busy = false

    let labelStore: LabelStore

    private let userId: String
    private let org: String
    private let token: String
    private let labelRepository: LabelRepository
    private let companyRepository: CompanyRepository

    init(
        userId: String, org: String, token: String, labelStore: LabelStore,
        labelRepository: LabelRepository = LabelRepository(), companyRepository: CompanyRepository = CompanyRepository()
    ) {
        self.userId = userId
        self.org = org
        self.token = token
        self.labelStore = labelStore
        self.labelRepository = labelRepository
        self.companyRepository = companyRepository
    }

    func loadRole() async {
        if let membership = try? await companyRepository.listMembers(token: token) {
            isAdmin = membership.items.first { $0.userId == userId }?.role == .admin
        } else {
            isAdmin = false
        }
    }

    func rename(_ label: AgendaLabel, to naam: String) async {
        let trimmed = naam.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            let updated = try await labelRepository.renameLabel(id: label.id, naam: trimmed, token: token)
            labelStore.update(updated)
        } catch {
            actionFailedAlert = true
        }
    }

    func updateColor(_ label: AgendaLabel, to kleur: String) async {
        do {
            let updated = try await labelRepository.updateColor(id: label.id, kleur: kleur, token: token)
            labelStore.update(updated)
        } catch {
            actionFailedAlert = true
        }
    }

    /// Geeft terug of het gelukt is: de view wiste de naam en sloot het formulier
    /// óók bij een fout, dus je zag "Mislukt" en was je invoer kwijt. De busy-guard
    /// voorkomt dat een dubbele tik twee labels met dezelfde naam aanmaakt.
    @discardableResult
    func create(naam: String, kleur: String) async -> Bool {
        let trimmed = naam.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !busy else { return false }
        busy = true
        defer { busy = false }
        do {
            let created = try await labelRepository.createLabel(
                org: org, naam: trimmed, kleur: kleur, volgorde: labelStore.orderedLabels.count, token: token
            )
            labelStore.add(created)
            return true
        } catch {
            actionFailedAlert = true
            return false
        }
    }

    /// Alleen admins mogen verwijderen (valkuil G). Geen server-round-trip voor
    /// een niet-admin — dezelfde client-side gate als MeldingenViewModel.canPost.
    func delete(_ label: AgendaLabel) async {
        guard isAdmin else { return }
        do {
            try await labelRepository.deleteLabel(id: label.id, token: token)
            labelStore.remove(id: label.id)
        } catch {
            actionFailedAlert = true
        }
    }
}
