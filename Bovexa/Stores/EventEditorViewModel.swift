import Foundation

/// Viewmodel voor het bewerkscherm van een afspraak. Opslaan: titel-check,
/// dubbele-boeking-check (fetchOwnEvents + findOverlap), dan updateEvent
/// (valkuil E) + herinnering plannen.
@MainActor
final class EventEditorViewModel: ObservableObject {
    @Published var title: String
    @Published var category: BovexaTheme.Category
    @Published private(set) var start: Date
    @Published private(set) var durationMin: Int
    @Published var notes: String
    @Published var klantNaam: String
    @Published var klantTelefoon: String
    @Published var reminderMin: Int
    @Published var assignee: [String]

    @Published private(set) var isSaving = false
    @Published var titleMissingAlert = false
    @Published var saveFailedAlert = false
    /// Niet-nil ⇒ caller toont "Dubbele boeking"-alert; bevestigen roept saveConfirmed() aan.
    @Published var overlapEvent: AgendaEvent?

    let originalEvent: AgendaEvent

    private let token: String
    private let repository: EventRepository
    private let reminderService: ReminderService

    init(
        event: AgendaEvent, token: String,
        repository: EventRepository = EventRepository(), reminderService: ReminderService = ReminderService()
    ) {
        originalEvent = event
        self.token = token
        self.repository = repository
        self.reminderService = reminderService

        title = event.title
        category = event.category ?? .work
        start = event.start
        durationMin = event.end.map { max(15, Int($0.timeIntervalSince(event.start) / 60)) } ?? 30
        notes = event.notes ?? ""
        klantNaam = event.klantNaam ?? ""
        klantTelefoon = event.klantTelefoon ?? ""
        reminderMin = event.reminderMin ?? 0
        assignee = event.assignee
    }

    func shiftDay(_ days: Int) {
        start = EventEditorStepping.shiftDay(start, by: days)
    }

    func shiftStart(minutes: Int) {
        start = EventEditorStepping.shiftMinutes(start, by: minutes)
    }

    func changeDuration(by delta: Int) {
        durationMin = EventEditorStepping.clampDuration(durationMin, delta: delta)
    }

    /// Titel-check + dubbele-boeking-check. Bij overlap zet dit `overlapEvent` in
    /// plaats van meteen op te slaan — de caller toont de alert.
    func save() async -> AgendaEvent? {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            titleMissingAlert = true
            return nil
        }
        let end = start.addingTimeInterval(Double(durationMin) * 60)
        do {
            let own = try await repository.fetchOwnEvents(userId: originalEvent.owner, token: token)
            if let overlap = EventOverlap.findOverlap(in: own, start: start, end: end, excludeId: EventHelpers.eventRecordId(originalEvent)) {
                overlapEvent = overlap
                return nil
            }
        } catch {
            saveFailedAlert = true
            return nil
        }
        return await performSave(end: end)
    }

    /// "Toch plannen" op de dubbele-boeking-alert — slaat direct op zonder opnieuw te checken.
    func saveConfirmed() async -> AgendaEvent? {
        overlapEvent = nil
        let end = start.addingTimeInterval(Double(durationMin) * 60)
        return await performSave(end: end)
    }

    private func performSave(end: Date) async -> AgendaEvent? {
        isSaving = true
        defer { isSaving = false }

        let payload = EventEditorPayloadBuilder.build(
            title: title, category: category, start: start, end: end, notes: notes,
            klantNaam: klantNaam, klantTelefoon: klantTelefoon, reminderMin: reminderMin,
            assignee: assignee, originalEvent: originalEvent
        )
        do {
            let updated = try await repository.updateEvent(recordId: EventHelpers.eventRecordId(originalEvent), payload: payload, token: token)
            await reminderService.schedule(eventId: updated.id, title: updated.title, start: updated.start, minutesBefore: reminderMin)
            return updated
        } catch {
            saveFailedAlert = true
            return nil
        }
    }
}
