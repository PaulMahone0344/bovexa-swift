import Foundation

/// Viewmodel voor het afspraak-detail: wie ziet welke knoppen (valkuil F — de server
/// bepaalt uiteindelijk wat mag, de client toont bewerken/verwijderen/zichtbaarheid
/// alleen voor de eigenaar) + optimistische updates met rollback bij falen.
@MainActor
final class EventDetailViewModel: ObservableObject {
    @Published private(set) var event: AgendaEvent
    @Published private(set) var isResponding = false
    @Published var deleteFailedAlert = false
    @Published var respondFailedAlert = false
    @Published var visibilityFailedAlert = false

    let currentUserId: String
    private let currentUserOrgId: String?
    private let token: String
    private let repository: EventRepository
    private let reminderService: ReminderService

    init(
        event: AgendaEvent, currentUserId: String, currentUserOrgId: String?, token: String,
        repository: EventRepository = EventRepository(), reminderService: ReminderService = ReminderService()
    ) {
        self.event = event
        self.currentUserId = currentUserId
        self.currentUserOrgId = currentUserOrgId
        self.token = token
        self.repository = repository
        self.reminderService = reminderService
    }

    var isOwner: Bool { event.owner == currentUserId }
    /// Valkuil B: extern event blokkeert altijd, ongeacht `owner` — dat mag nooit de
    /// enige reden zijn waarom bewerken/verwijderen/toewijzen dicht staat.
    var canDelete: Bool { isOwner && !event.isExternal }
    var canEdit: Bool { isOwner && !event.isExternal }
    var showVisibilityPicker: Bool { isOwner && currentUserOrgId != nil && !event.isExternal }

    var isAssignedToMe: Bool { event.assignee.contains(currentUserId) }
    var myAssignmentStatus: String? {
        AssignmentHelpers.assignmentStatus(assignees: event.assignee, statusMap: event.assigneeStatus, userId: currentUserId)
    }
    var canRespond: Bool { !isResponding && myAssignmentStatus == "pending" && !event.isExternal }

    /// Valkuil D: oude waarden (team/manager/busy/people/leeg) tonen als "company" ("Bedrijf").
    var normalizedVisibility: String {
        event.visibilityRaw == "private" ? "private" : "company"
    }

    /// EventEditor heeft al opgeslagen — de detailweergave toont gewoon de nieuwe waarden.
    func applyEditorSave(_ updated: AgendaEvent) {
        event = updated
    }

    func delete() async -> Bool {
        guard canDelete else { return false }
        do {
            try await repository.deleteEvent(recordId: EventHelpers.eventRecordId(event), token: token)
            // Bij een herhaling is `event.id` het bezetting-id ("recordId:datum"),
            // terwijl de herinnering op het record-id gepland is. Op het bezetting-id
            // annuleren liet de notificatie staan voor een verwijderde afspraak.
            reminderService.cancel(eventId: EventHelpers.eventRecordId(event))
            return true
        } catch {
            deleteFailedAlert = true
            return false
        }
    }

    /// Valkuil B: schrijft alleen jouw sleutel; weigeren laat de afspraak in het model
    /// staan — de caller navigeert terug (afspraak verdwijnt daarna uit de agenda-lijst).
    func respond(_ status: String) async {
        guard canRespond else { return }
        let previous = event
        isResponding = true
        event = event.withAssigneeStatus(previous.assigneeStatus.merging([currentUserId: status]) { _, new in new })
        do {
            event = try await repository.respondToAssignment(event: previous, userId: currentUserId, status: status, token: token)
        } catch {
            event = previous
            respondFailedAlert = true
        }
        isResponding = false
    }

    func changeVisibility(_ visibility: String) async {
        guard showVisibilityPicker else { return }
        let previous = event
        event = event.withVisibility(visibility, viewers: EventViewers.union(previous.viewers, assignees: previous.assignee))
        do {
            event = try await repository.updateVisibility(
                recordId: EventHelpers.eventRecordId(previous), visibility: visibility,
                viewers: previous.viewers, assignees: previous.assignee, token: token
            )
        } catch {
            event = previous
            visibilityFailedAlert = true
        }
    }
}
