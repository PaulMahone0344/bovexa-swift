import Foundation

/// Bouwt de EventUpdatePayload uit het EventEditor-formulier — viewers-union
/// (valkuil C) en assignee_status-map (valkuil B), zoals save() in de RN-app.
enum EventEditorPayloadBuilder {
    static func build(
        title: String, category: BovexaTheme.Category?, start: Date, end: Date, notes: String,
        klantNaam: String, klantTelefoon: String, reminders: [Int], assignee: [String],
        originalEvent: AgendaEvent, label: String? = nil, contact: String? = nil,
        contacten: [String] = [],
        visibility: String? = nil
    ) -> EventUpdatePayload {
        EventUpdatePayload(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category,
            start: start,
            end: end,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            klantNaam: klantNaam.trimmingCharacters(in: .whitespacesAndNewlines),
            klantTelefoon: klantTelefoon.trimmingCharacters(in: .whitespacesAndNewlines),
            reminders: reminders,
            assignee: assignee,
            viewers: EventViewers.union(originalEvent.viewers, assignees: assignee),
            assigneeStatus: AssignmentHelpers.nextStatusMap(assignees: assignee, ownerId: originalEvent.owner, previous: originalEvent.assigneeStatus),
            label: label,
            contact: contact,
            contacten: contacten,
            visibility: visibility
        )
    }
}
