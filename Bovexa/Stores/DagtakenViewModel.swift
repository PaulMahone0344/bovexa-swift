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
    @Published private(set) var teamTasks: [AgendaTask] = []
    @Published var deleteTeamTaskFailedAlert = false
    /// Wissen uit het lokale archief vraagt een tweede tik binnen dit venster
    /// (valkuil G); die vervalt vanzelf.
    @Published private(set) var confirmDeleteId: String?

    let memberColors = MemberColors()

    private let planningStore: PlanningNoteStore
    private let taskRepository: TaskRepository
    private let eventRepository: EventRepository
    private let confirmDeleteTimeout: Duration
    private var confirmDeleteTask: Task<Void, Never>?

    init(
        planningStore: PlanningNoteStore = PlanningNoteStore(),
        taskRepository: TaskRepository = TaskRepository(),
        eventRepository: EventRepository = EventRepository(),
        confirmDeleteTimeout: Duration = .seconds(3)
    ) {
        self.planningStore = planningStore
        self.taskRepository = taskRepository
        self.eventRepository = eventRepository
        self.confirmDeleteTimeout = confirmDeleteTimeout
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

    /// Herlaadt bedrijfsinfo + team-taken samen — aanroeper roept dit zowel bij het
    /// eerste tonen van het scherm als bij terugkeer ernaartoe (RN gebruikt hiervoor
    /// useFocusEffect; realtime bestaat hier niet, dus geen abonnement).
    func load(userId: String, org: String?, token: String) async {
        async let orgInfo: Void = loadOrgInfo(token: token)
        async let team: Void = loadTeamTasks(org: org, token: token)
        _ = await (orgInfo, team)
    }

    /// Valkuil C: zonder bedrijf bestaat de teamhelft niet — geen netwerkverzoek.
    func loadTeamTasks(org: String?, token: String) async {
        guard org != nil else {
            teamTasks = []
            return
        }
        do {
            teamTasks = try await taskRepository.fetchTasks(token: token)
        } catch {
            teamTasks = []
        }
    }

    func startEdit(_ note: PlanningNote) {
        editingId = note.id
        draft = PlanningNoteFactory.draftText(for: note)
    }

    func cancelEdit() {
        editingId = nil
        draft = ""
    }

    func toggleNote(_ id: String) {
        planningStore.toggle(id: id)
    }

    func archive(_ id: String) {
        planningStore.setArchived(id: id, archived: true)
    }

    func restore(_ id: String) {
        planningStore.setArchived(id: id, archived: false)
    }

    /// Eerste tik markeert, tweede tik binnen `confirmDeleteTimeout` wist definitief.
    func requestDeleteLocalNote(_ id: String) {
        confirmDeleteTask?.cancel()

        if confirmDeleteId == id {
            confirmDeleteId = nil
            planningStore.delete(id: id)
            return
        }

        confirmDeleteId = id
        let timeout = confirmDeleteTimeout
        confirmDeleteTask = Task { [weak self] in
            try? await Task.sleep(for: timeout)
            guard !Task.isCancelled else { return }
            self?.confirmDeleteId = nil
        }
    }

    /// Valkuil E: alleen eigen team-taken mogen worden afgevinkt.
    func toggleTeamTask(_ task: AgendaTask, userId: String, token: String) async {
        guard task.owner == userId else { return }
        let previousStatus = task.status
        let previousCompletedAt = task.completedAt
        let nextStatus: TaskStatus = task.status == .klaar ? .open : .klaar
        let nextCompletedAt: Date? = nextStatus == .klaar ? Date() : nil
        applyTeamTaskStatus(id: task.id, status: nextStatus, completedAt: nextCompletedAt)

        do {
            let updated = try await taskRepository.setStatus(id: task.id, status: nextStatus, completedAt: nextCompletedAt, token: token)
            applyTeamTaskStatus(id: task.id, status: updated.status, completedAt: updated.completedAt)
        } catch {
            applyTeamTaskStatus(id: task.id, status: previousStatus, completedAt: previousCompletedAt)
        }
    }

    /// Valkuil E: alleen eigen team-taken mogen worden gewist.
    func deleteTeamTask(_ task: AgendaTask, userId: String, token: String) async {
        guard task.owner == userId else { return }
        do {
            try await taskRepository.deleteTask(id: task.id, token: token)
            teamTasks.removeAll { $0.id == task.id }
        } catch {
            deleteTeamTaskFailedAlert = true
        }
    }

    private func applyTeamTaskStatus(id: String, status: TaskStatus, completedAt: Date?) {
        teamTasks = teamTasks.map { $0.id == id ? $0.withStatus(status, completedAt: completedAt) : $0 }
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
            let created = try await taskRepository.createTask(owner: userId, org: org, title: title, notes: body, visibility: visibility, token: token)
            teamTasks = [created] + teamTasks
            draft = ""
            visibility = .private
        } catch {
            createFailedAlert = true
        }
    }
}
