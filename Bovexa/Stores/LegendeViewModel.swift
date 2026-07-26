import Foundation

/// Beheer van de labellegenda (m7 plak 6): hernoemen/kleur wijzigen/toevoegen mag
/// iedereen in het bedrijf, verwijderen alleen admins (valkuil G) — dat raakt
/// afspraken van collega's. Rol wordt hetzelfde opgehaald als in MeldingenViewModel.
@MainActor
final class LegendeViewModel: ObservableObject {
    @Published private(set) var isAdmin = false
    @Published var actionFailedAlert = false

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

    func create(naam: String, kleur: String) async {
        let trimmed = naam.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            let created = try await labelRepository.createLabel(
                org: org, naam: trimmed, kleur: kleur, volgorde: labelStore.orderedLabels.count, token: token
            )
            labelStore.add(created)
        } catch {
            actionFailedAlert = true
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
