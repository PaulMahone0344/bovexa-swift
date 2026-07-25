import Foundation

/// Viewmodel voor de Dagtaken-composer + "Mijn dagtaken". Beslist bij "Toevoegen"
/// tussen bewerken, een team-taak (org + visibility != private) en een lokale
/// dagtaak — zelfde beslisboom als submit() in taken.tsx.
@MainActor
final class DagtakenViewModel: ObservableObject {
    @Published var draft = ""
    @Published var visibility: TaskVisibility = .private
    @Published private(set) var editingId: String?
    @Published private(set) var busy = false
    @Published var createFailedAlert = false
    @Published private(set) var orgName: String?

    let memberColors = MemberColors()

    private let planningStore: PlanningNoteStore
    private let taskRepository: TaskRepository
    private let eventRepository: EventRepository

    init(
        planningStore: PlanningNoteStore = PlanningNoteStore(),
        taskRepository: TaskRepository = TaskRepository(),
        eventRepository: EventRepository = EventRepository()
    ) {
        self.planningStore = planningStore
        self.taskRepository = taskRepository
        self.eventRepository = eventRepository
    }

    var notes: [PlanningNote] { planningStore.notes }
    var openNotes: [PlanningNote] { notes.filter { !$0.archived } }
    var archivedNotes: [PlanningNote] { notes.filter { $0.archived } }
    var isEditing: Bool { editingId != nil }
    var canSubmit: Bool { !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !busy }

    /// Faalt stil, net als EventRepository.listMembers: geen bedrijf gekoppeld of een
    /// netwerkfout betekent gewoon geen bedrijfsnaam/collega-kleuren.
    func loadOrgInfo(token: String) async {
        guard let response = await eventRepository.listMembers(token: token) else { return }
        memberColors.prime(members: response.items, org: response.org)
        orgName = memberColors.orgName
    }

    func startEdit(_ note: PlanningNote) {
        editingId = note.id
        draft = PlanningNoteFactory.draftText(for: note)
    }

    func cancelEdit() {
        editingId = nil
        draft = ""
    }

    func archive(_ id: String) {
        planningStore.setArchived(id: id, archived: true)
    }

    func submit(userId: String, org: String?, token: String) async {
        guard canSubmit else { return }

        if let editingId {
            planningStore.update(id: editingId, text: draft)
            self.editingId = nil
            draft = ""
            return
        }

        if org != nil, visibility != .private {
            await createTeamTask(userId: userId, org: org, token: token)
            return
        }

        planningStore.add(text: draft)
        draft = ""
    }

    private func createTeamTask(userId: String, org: String?, token: String) async {
        guard let (title, body) = PlanningNoteFactory.parse(draft) else { return }
        busy = true
        defer { busy = false }
        do {
            _ = try await taskRepository.createTask(owner: userId, org: org, title: title, notes: body, visibility: visibility, token: token)
            draft = ""
            visibility = .private
        } catch {
            createFailedAlert = true
        }
    }
}
