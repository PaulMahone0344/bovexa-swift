import Foundation

/// Bouwt de AppointmentCreatePayload uit een AI-voorstel — geport uit appointmentToEvent()
/// + de confirm()-uitbreiding (reminder_min/assignee_status) in
/// ~/Desktop/agenda-app/src/lib/aiPlanner.ts en ~/Desktop/agenda-app/src/hooks/useAiPlanner.ts.
enum AppointmentPayloadBuilder {
    /// - Parameters:
    ///   - org: `user.default_org`. `nil` ⇒ valkuil C: toewijzingen worden genegeerd en
    ///     visibility staat altijd op "private", ongeacht wat is meegegeven.
    ///   - visibility: gebruikerskeuze uit VisibilityPickerView ("private"/"company"), alleen
    ///     relevant mét org.
    ///   - viewers: aangevinkte collega's bij zichtbaarheid "people" (legacy-waarde, komt niet
    ///     meer uit de picker maar kan nog uit opgeslagen state komen).
    static func build(
        appointment: ProposedAppointment,
        ownerId: String,
        rawInput: String,
        org: String?,
        visibility: String,
        viewers: [String],
        assignees: [String],
        reminderMin: Int,
        label: String? = nil
    ) -> AppointmentCreatePayload {
        let range = AppointmentRange.range(for: appointment)
        let isWork = appointment.category == .work || appointment.category == .focus

        let effectiveAssignees = org != nil ? assignees : []
        let effectiveVisibility = org != nil ? visibility : "private"
        // Valkuil D: toegewezenen altijd óók in viewers, ongeacht visibility.
        let baseViewers = effectiveVisibility == "people" ? viewers : []
        let unionViewers = EventViewers.union(baseViewers, assignees: effectiveAssignees)

        return AppointmentCreatePayload(
            owner: ownerId,
            org: org ?? "",
            title: appointment.title,
            category: appointment.category,
            calendar: isWork ? "work" : "private",
            location: appointment.location ?? "",
            recurrence: appointment.recurrence ?? "",
            klantNaam: appointment.klantNaam ?? "",
            klantTelefoon: appointment.klantTelefoon ?? "",
            start: range.start,
            end: range.end,
            visibility: effectiveVisibility,
            viewers: unionViewers,
            assignee: effectiveAssignees,
            rawInput: rawInput,
            reminderMin: reminderMin,
            assigneeStatus: AssignmentHelpers.nextStatusMap(assignees: effectiveAssignees, ownerId: ownerId),
            label: label
        )
    }
}
