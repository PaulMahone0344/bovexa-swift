import Foundation

/// Viewmodel voor de Dagtaken-composer + "Mijn dagtaken". Beslist bij "Toevoegen"
/// tussen bewerken, een team-taak (org + visibility != private) en een lokale
/// dagtaak — zelfde beslisboom als submit() in taken.tsx.
@MainActor
final class DagtakenViewModel: ObservableObject {
    @Published var draft = ""
    @Published var visibility: TaskVisibility = .private
    /// Collega's die deze dagtaak op hun scherm moeten krijgen. Zodra hier iemand
    /// in staat gaat de taak naar de server met visibility 'people' — ook als je
    /// Privé koos: een taak die op het scherm van een ander hoort te komen kan
    /// niet in de lokale UserDefaults blijven staan. Leeg = het oude gedrag
    /// (privé blijft lokaal, bedrijf blijft company).
    @Published var assignees: [String] = []
    @Published private(set) var editingId: String?
    @Published private(set) var busy = false
    @Published var createFailedAlert = false
    @Published private(set) var orgName: String?
    @Published private(set) var teamTasks: [AgendaTask] = []
    /// Aan als de laatste fetch mislukte; de vorige gegevens blijven staan.
    @Published private(set) var loadFailed = false
    /// Aan tijdens de eerste fetch van de bedrijfslijst: zonder dit stond er
    /// "Nog geen gedeelde dagtaken" terwijl er nog geladen werd (4l).
    @Published private(set) var teamLoading = false

    @Published var deleteTeamTaskFailedAlert = false
    /// Wissen uit het lokale archief vraagt een tweede tik binnen dit venster
    /// (valkuil G); die vervalt vanzelf.
    @Published private(set) var confirmDeleteId: String?
    /// Spiegel van `planningStore.notes`. Was een computed property, maar
    /// PlanningNoteStore is geen ObservableObject: afvinken, archiveren en
    /// terugzetten veranderden de waarde wél, maar publiceerden niets, dus het
    /// scherm bleef staan tot een willekeurige herrender (tab wisselen, sheet
    /// openen). Elke mutatie loopt nu via `syncNotes()`.
    @Published private(set) var notes: [PlanningNote] = []

    let memberColors = MemberColors()

    private let planningStore: PlanningNoteStore
    private let taskRepository: TaskRepository
    private let eventRepository: EventRepository
    private let confirmDeleteTimeout: Duration
    private var confirmDeleteTask: Task<Void, Never>?
    private var boundUserId: String?

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

    private func syncNotes() { notes = planningStore.notes }

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

    /// De lokale dagtaken hangen sinds M11 plak 3c aan de userId. Elk pad dat de
    /// gebruiker kent bindt de store, want een mutatie op een ongebonden store doet
    /// stil niets — en dat is precies het soort fout dat pas op een toestel opvalt.
    private func bindStore(to userId: String) {
        guard boundUserId != userId else { return }
        boundUserId = userId
        planningStore.reload(userId: userId)
        syncNotes()
    }

    /// Herlaadt bedrijfsinfo + team-taken samen — aanroeper roept dit zowel bij het
    /// eerste tonen van het scherm als bij terugkeer ernaartoe (RN gebruikt hiervoor
    /// useFocusEffect; realtime bestaat hier niet, dus geen abonnement).
    func load(userId: String, org: String?, token: String) async {
        // Synchroon en als eerste: de lijst moet er staan vóór het scherm tekent.
        bindStore(to: userId)

        async let orgInfo: Void = loadOrgInfo(token: token)
        async let team: Void = loadTeamTasks(org: org, token: token)
        _ = await (orgInfo, team)
    }

    /// Valkuil C: zonder bedrijf bestaat de teamhelft niet — geen netwerkverzoek.
    func loadTeamTasks(org: String?, token: String) async {
        guard org != nil else {
            teamTasks = []
            loadFailed = false
            return
        }
        teamLoading = teamTasks.isEmpty
        defer { teamLoading = false }
        do {
            teamTasks = try await taskRepository.fetchTasks(token: token)
            loadFailed = false
        } catch {
            // Vorige lijst laten staan: leeg maken leest als "er zijn geen
            // bedrijfstaken", en dat is iets anders dan "ik kon ze niet ophalen".
            loadFailed = true
        }
    }

    /// De bedrijfslijst zoals één persoon hem hoort te zien: alleen wat aan hem is
    /// toegewezen, plus wat hij zelf heeft aangemaakt. Een medewerker zag hiervoor
    /// élke bedrijfstaak, ook die van een collega.
    ///
    /// Een taak zonder toegewezen personen is aan het hele team gericht en blijft
    /// dus staan; die "krijg" je net zo goed.
    func zichtbareTeamTasks(userId: String) -> [AgendaTask] {
        teamTasks.filter { TaskPermissions.isGerichtAan(userId, task: $0) }
    }

    /// Wie de taak heeft afgevinkt, voor de regel onder de titel. `completed_by`
    /// staat sinds 7 september op de server en is de enige bron die ook bij een
    /// teambrede taak klopt. Oudere taken hebben dat veld niet; daar valt de app
    /// terug op de toegewezen persoon, en alleen als dat er precies één is.
    /// Lukt ook dat niet, dan blijft dit leeg en staat er alleen een tijdstip.
    func afgevinktDoor(_ task: AgendaTask, currentUserId: String) -> String {
        if let wie = task.completedBy {
            return naamVan(wie, currentUserId: currentUserId)
        }
        let toegewezen = task.viewers.filter { $0 != task.owner }
        guard toegewezen.count == 1, let wie = toegewezen.first else { return "" }
        return naamVan(wie, currentUserId: currentUserId)
    }

    private func naamVan(_ userId: String, currentUserId: String) -> String {
        userId == currentUserId ? "Jij" : (memberColors.firstName(for: userId) ?? "Collega")
    }

    /// "Jan, Piet" voor een toegewezen taak; "Jij" als jij het bent. Leeg bij een
    /// taak voor het hele bedrijf — daar hoort geen namenrij bij.
    func assigneeLabel(for task: AgendaTask, currentUserId: String) -> String {
        let others = task.viewers.filter { $0 != task.owner }
        guard !others.isEmpty else { return "" }
        return others
            .map { $0 == currentUserId ? "Jij" : (memberColors.firstName(for: $0) ?? "Collega") }
            .joined(separator: ", ")
    }

    func startEdit(_ note: PlanningNote) {
        editingId = note.id
        draft = PlanningNoteFactory.draftText(for: note)
    }

    func cancelEdit() {
        editingId = nil
        draft = ""
        assignees = []
    }

    func toggleNote(_ id: String) {
        planningStore.toggle(id: id)
        syncNotes()
    }

    func archive(_ id: String) {
        planningStore.setArchived(id: id, archived: true)
        syncNotes()
    }

    func restore(_ id: String) {
        planningStore.setArchived(id: id, archived: false)
        syncNotes()
    }

    /// Eerste tik markeert, tweede tik binnen `confirmDeleteTimeout` wist definitief.
    func requestDeleteLocalNote(_ id: String) {
        confirmDeleteTask?.cancel()

        if confirmDeleteId == id {
            confirmDeleteId = nil
            planningStore.delete(id: id)
            syncNotes()
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

    /// Afvinken mag ook een collega bij een gedeelde bedrijfstaak (27 juli): wie hem
    /// doet, vinkt hem af. Wissen blijft van de eigenaar.
    func toggleTeamTask(_ task: AgendaTask, userId: String, token: String) async {
        guard TaskPermissions.canToggle(task, userId: userId) else { return }
        let previousStatus = task.status
        let previousCompletedAt = task.completedAt
        let previousCompletedBy = task.completedBy
        let nextStatus: TaskStatus = task.status == .klaar ? .open : .klaar
        let nextCompletedAt: Date? = nextStatus == .klaar ? Date() : nil
        // Wie afvinkt hoort erbij te staan, ook bij een taak voor het hele team;
        // uitvinken maakt allebei de velden weer leeg.
        let nextCompletedBy: String? = nextStatus == .klaar ? userId : nil
        applyTeamTaskStatus(id: task.id, status: nextStatus, completedAt: nextCompletedAt, completedBy: nextCompletedBy)

        do {
            let updated = try await taskRepository.setStatus(
                id: task.id, status: nextStatus, completedAt: nextCompletedAt, completedBy: nextCompletedBy, token: token
            )
            applyTeamTaskStatus(id: task.id, status: updated.status, completedAt: updated.completedAt, completedBy: updated.completedBy)
        } catch {
            applyTeamTaskStatus(id: task.id, status: previousStatus, completedAt: previousCompletedAt, completedBy: previousCompletedBy)
        }
    }

    /// Valkuil E: alleen eigen team-taken mogen worden gewist.
    func deleteTeamTask(_ task: AgendaTask, userId: String, token: String) async {
        guard TaskPermissions.canDelete(task, userId: userId) else { return }
        do {
            try await taskRepository.deleteTask(id: task.id, token: token)
            teamTasks.removeAll { $0.id == task.id }
        } catch {
            deleteTeamTaskFailedAlert = true
        }
    }

    /// Titel/notitie van een eigen team-dagtaak aanpassen. Geeft terug of het
    /// lukte, zodat het detailscherm het bewerkveld pas sluit als de server mee is.
    @discardableResult
    func updateTeamTask(_ task: AgendaTask, title: String, notes: String, userId: String, token: String) async -> Bool {
        guard TaskPermissions.canEdit(task, userId: userId) else { return false }
        let schoon = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !schoon.isEmpty else { return false }
        do {
            let updated = try await taskRepository.updateTask(id: task.id, title: schoon, notes: notes, token: token)
            teamTasks = teamTasks.map { $0.id == updated.id ? updated : $0 }
            return true
        } catch {
            return false
        }
    }

    private func applyTeamTaskStatus(id: String, status: TaskStatus, completedAt: Date?, completedBy: String?) {
        teamTasks = teamTasks.map { $0.id == id ? $0.withStatus(status, completedAt: completedAt, completedBy: completedBy) : $0 }
    }

    func submit(userId: String, org: String?, token: String) async {
        guard canSubmit else { return }
        bindStore(to: userId)

        if let editingId {
            planningStore.update(id: editingId, text: draft)
            syncNotes()
            self.editingId = nil
            draft = ""
            return
        }

        // Toegewezen personen wegen zwaarder dan de keuze Privé/Bedrijf: zij
        // moeten de taak zien, dus hij gaat naar de server met visibility
        // 'people' in plaats van in de lokale lijst te blijven.
        if org != nil, visibility != .private || !assignees.isEmpty {
            await createTeamTask(userId: userId, org: org, token: token)
            return
        }

        planningStore.add(text: draft)
        syncNotes()
        draft = ""
    }

    private func createTeamTask(userId: String, org: String?, token: String) async {
        guard let (title, body) = PlanningNoteFactory.parse(draft) else { return }
        busy = true
        defer { busy = false }
        // Jezelf erbij: als eigenaar zie je hem toch al, maar de server-rule voor
        // 'people' kijkt naar viewers en zonder jezelf verdween je eigen taak uit
        // je lijst zodra je hem aan iemand toewees.
        let viewers = assignees.isEmpty ? [] : Array(Set(assignees + [userId]))
        let effectiveVisibility: TaskVisibility = assignees.isEmpty ? visibility : .people
        do {
            let created = try await taskRepository.createTask(
                owner: userId, org: org, title: title, notes: body,
                visibility: effectiveVisibility, viewers: viewers, token: token
            )
            teamTasks = [created] + teamTasks
            draft = ""
            visibility = .private
            assignees = []
        } catch {
            createFailedAlert = true
        }
    }
}
