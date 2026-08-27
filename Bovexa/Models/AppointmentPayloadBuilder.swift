import Foundation

/// Bouwt de AppointmentCreatePayload voor beide aanmaakroutes — geport uit
/// appointmentToEvent() + de confirm()-uitbreiding (reminder_min/assignee_status) in
/// ~/Desktop/agenda-app/src/lib/aiPlanner.ts en ~/Desktop/agenda-app/src/hooks/useAiPlanner.ts.
///
/// Valkuil A van M12: de AI-planner en het handmatige formulier maken allebei een
/// afspraak aan en moeten exact dezelfde velden schrijven. Daarom lopen ze hier
/// door dezelfde `make()`; alleen `source` en `raw_input` verschillen.
enum AppointmentPayloadBuilder {
    /// AI-tak: uit een voorstel van de planner. Schrijft source 'nl'.
    ///
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
        label: String? = nil,
        contact: String? = nil,
        /// Naam en telefoon van het gekozen contact: die winnen van wat de planner
        /// uit de zin haalde, en gaan als klant_naam mee zodat een collega de klant
        /// blijft zien (het contact zelf is privé en niet uitleesbaar voor hem).
        contactNaam: String? = nil,
        contactTelefoon: String? = nil
    ) -> AppointmentCreatePayload {
        let range = AppointmentRange.range(for: appointment)
        return make(
            title: appointment.title,
            category: appointment.category,
            start: range.start,
            end: range.end,
            location: appointment.location ?? "",
            recurrence: appointment.recurrence ?? "",
            klantNaam: contactNaam ?? appointment.klantNaam ?? "",
            klantTelefoon: contactTelefoon ?? appointment.klantTelefoon ?? "",
            ownerId: ownerId,
            org: org,
            visibility: visibility,
            viewers: viewers,
            assignees: assignees,
            reminderMin: reminderMin,
            label: label,
            contact: contact,
            source: "nl",
            rawInput: rawInput
        )
    }

    /// Handmatige tak (M12): uit het EventEditor-formulier in create-modus. Zelfde
    /// velden, maar source 'manual' en een lege raw_input — er is geen zin die de
    /// gebruiker heeft ingesproken of getypt. Locatie en herhaling kent het
    /// formulier niet en blijven leeg, net als bij een voorstel zonder die velden.
    static func buildManual(
        title: String,
        category: BovexaTheme.Category?,
        start: Date,
        end: Date,
        ownerId: String,
        org: String?,
        visibility: String,
        viewers: [String] = [],
        assignees: [String],
        reminderMin: Int,
        label: String? = nil,
        contact: String? = nil,
        klantNaam: String = "",
        klantTelefoon: String = "",
        notes: String = ""
    ) -> AppointmentCreatePayload {
        make(
            title: title,
            category: category,
            start: start,
            end: end,
            location: "",
            recurrence: "",
            klantNaam: klantNaam,
            klantTelefoon: klantTelefoon,
            ownerId: ownerId,
            org: org,
            visibility: visibility,
            viewers: viewers,
            assignees: assignees,
            reminderMin: reminderMin,
            label: label,
            contact: contact,
            source: "manual",
            rawInput: "",
            notes: notes
        )
    }

    /// De enige plek waar een create-payload wordt samengesteld: org-regels
    /// (valkuil C), viewers-union (valkuil D) en de calendar-afleiding staan hier
    /// één keer, voor beide takken.
    private static func make(
        title: String,
        category: BovexaTheme.Category?,
        start: Date,
        end: Date,
        location: String,
        recurrence: String,
        klantNaam: String,
        klantTelefoon: String,
        ownerId: String,
        org: String?,
        visibility: String,
        viewers: [String],
        assignees: [String],
        reminderMin: Int,
        label: String?,
        contact: String?,
        source: String,
        rawInput: String,
        notes: String = ""
    ) -> AppointmentCreatePayload {
        let isWork = category == .work || category == .focus

        let effectiveAssignees = org != nil ? assignees : []
        let effectiveVisibility = org != nil ? visibility : "private"
        // Valkuil D: toegewezenen altijd óók in viewers, ongeacht visibility.
        let baseViewers = effectiveVisibility == "people" ? viewers : []
        let unionViewers = EventViewers.union(baseViewers, assignees: effectiveAssignees)

        return AppointmentCreatePayload(
            owner: ownerId,
            org: org ?? "",
            title: title,
            category: category,
            calendar: isWork ? "work" : "private",
            location: location,
            recurrence: recurrence,
            klantNaam: klantNaam,
            klantTelefoon: klantTelefoon,
            start: start,
            end: end,
            visibility: effectiveVisibility,
            viewers: unionViewers,
            assignee: effectiveAssignees,
            rawInput: rawInput,
            reminderMin: reminderMin,
            assigneeStatus: AssignmentHelpers.nextStatusMap(assignees: effectiveAssignees, ownerId: ownerId),
            source: source,
            label: label,
            contact: contact,
            notes: notes.isEmpty ? nil : notes
        )
    }
}
