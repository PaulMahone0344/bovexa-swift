import Testing
import Foundation
@testable import Bovexa

/// AppointmentPayloadBuilder — valkuilen A (velden + source 'nl'), C (org-afhankelijk
/// gedrag), D (viewers-union). Geport uit appointmentToEvent()/confirm() in
/// ~/Desktop/agenda-app/src/lib/aiPlanner.ts en useAiPlanner.ts.
struct AppointmentPayloadBuilderTests {
    private func appointment(category: BovexaTheme.Category = .body, location: String? = nil, recurrence: String? = nil) -> ProposedAppointment {
        ProposedAppointment(title: "Tandarts", date: "2026-08-03", start: "09:00", end: "09:30", category: category, location: location, recurrence: recurrence)
    }

    @Test func sourceIsAlwaysNl() {
        let payload = AppointmentPayloadBuilder.build(
            appointment: appointment(), ownerId: "u1", rawInput: "raw", org: nil,
            visibility: "private", viewers: [], assignees: [], reminderMin: 0
        )
        #expect(payload.requestBody["source"] as? String == "nl")
    }

    @Test func calendarIsWorkForWorkAndFocusCategories() {
        for category: BovexaTheme.Category in [.work, .focus] {
            let payload = AppointmentPayloadBuilder.build(
                appointment: appointment(category: category), ownerId: "u1", rawInput: "raw", org: "org1",
                visibility: "company", viewers: [], assignees: [], reminderMin: 0
            )
            #expect(payload.calendar == "work")
        }
    }

    @Test func calendarIsPrivateForSocialAndBodyCategories() {
        for category: BovexaTheme.Category in [.social, .body] {
            let payload = AppointmentPayloadBuilder.build(
                appointment: appointment(category: category), ownerId: "u1", rawInput: "raw", org: "org1",
                visibility: "private", viewers: [], assignees: [], reminderMin: 0
            )
            #expect(payload.calendar == "private")
        }
    }

    @Test func withoutOrgAssigneesAreIgnoredAndVisibilityForcedPrivate() {
        let payload = AppointmentPayloadBuilder.build(
            appointment: appointment(), ownerId: "u1", rawInput: "raw", org: nil,
            visibility: "company", viewers: ["u2"], assignees: ["u2"], reminderMin: 0
        )
        #expect(payload.org == "")
        #expect(payload.visibility == "private")
        #expect(payload.assignee.isEmpty)
        #expect(payload.viewers.isEmpty)
        #expect(payload.assigneeStatus.isEmpty)
    }

    @Test func withOrgVisibilityAndAssigneesAreRespected() {
        let payload = AppointmentPayloadBuilder.build(
            appointment: appointment(category: .work), ownerId: "u1", rawInput: "raw", org: "org1",
            visibility: "company", viewers: [], assignees: ["u2"], reminderMin: 0
        )
        #expect(payload.org == "org1")
        #expect(payload.visibility == "company")
        #expect(payload.assignee == ["u2"])
        #expect(payload.assigneeStatus == ["u2": "pending"])
    }

    @Test func assigneesAreAlwaysUnionedIntoViewersRegardlessOfVisibility() {
        let payload = AppointmentPayloadBuilder.build(
            appointment: appointment(), ownerId: "u1", rawInput: "raw", org: "org1",
            visibility: "company", viewers: [], assignees: ["u2", "u3"], reminderMin: 0
        )
        #expect(payload.viewers == ["u2", "u3"])
    }

    @Test func peopleVisibilityUnionsSelectedViewersWithAssignees() {
        let payload = AppointmentPayloadBuilder.build(
            appointment: appointment(), ownerId: "u1", rawInput: "raw", org: "org1",
            visibility: "people", viewers: ["u2"], assignees: ["u3"], reminderMin: 0
        )
        #expect(payload.viewers == ["u2", "u3"])
    }

    @Test func ownerAssigningSelfIsAutoAccepted() {
        let payload = AppointmentPayloadBuilder.build(
            appointment: appointment(), ownerId: "u1", rawInput: "raw", org: "org1",
            visibility: "company", viewers: [], assignees: ["u1"], reminderMin: 0
        )
        #expect(payload.assigneeStatus == ["u1": "accepted"])
    }

    @Test func rawInputAndReminderMinAndOptionalFieldsPassThrough() {
        let payload = AppointmentPayloadBuilder.build(
            appointment: appointment(location: "Kantoor", recurrence: "FREQ=WEEKLY"), ownerId: "u1", rawInput: "Morgen tandarts",
            org: "org1", visibility: "private", viewers: [], assignees: [], reminderMin: 60
        )
        #expect(payload.rawInput == "Morgen tandarts")
        #expect(payload.reminderMin == 60)
        #expect(payload.location == "Kantoor")
        #expect(payload.recurrence == "FREQ=WEEKLY")
    }

    @Test func missingOptionalFieldsBecomeEmptyStrings() {
        let payload = AppointmentPayloadBuilder.build(
            appointment: appointment(), ownerId: "u1", rawInput: "raw", org: "org1",
            visibility: "private", viewers: [], assignees: [], reminderMin: 0
        )
        #expect(payload.location == "")
        #expect(payload.recurrence == "")
        #expect(payload.klantNaam == "")
        #expect(payload.klantTelefoon == "")
    }

    @Test func withoutLabelOmitsFieldFromRequestBody() {
        let payload = AppointmentPayloadBuilder.build(
            appointment: appointment(), ownerId: "u1", rawInput: "raw", org: "org1",
            visibility: "private", viewers: [], assignees: [], reminderMin: 0
        )
        #expect(payload.requestBody["label"] == nil)
    }

    @Test func withLabelIncludesFieldInRequestBody() {
        let payload = AppointmentPayloadBuilder.build(
            appointment: appointment(), ownerId: "u1", rawInput: "raw", org: "org1",
            visibility: "private", viewers: [], assignees: [], reminderMin: 0, label: "l1"
        )
        #expect(payload.requestBody["label"] as? String == "l1")
    }

    // MARK: - handmatige tak (M12 plak 2)

    @Test func manualBuildWritesSourceManualAndEmptyRawInput() {
        let start = Date(timeIntervalSince1970: 1_785_000_000)
        let payload = AppointmentPayloadBuilder.buildManual(
            title: "Kapper", category: .work, start: start, end: start.addingTimeInterval(1800),
            ownerId: "u1", org: "org1", visibility: "company", assignees: [], reminderMin: 0
        )
        #expect(payload.requestBody["source"] as? String == "manual")
        #expect(payload.requestBody["raw_input"] as? String == "")
    }

    @Test func manualBuildWithoutOrgForcesPrivateAndDropsAssignees() {
        let start = Date(timeIntervalSince1970: 1_785_000_000)
        let payload = AppointmentPayloadBuilder.buildManual(
            title: "Kapper", category: .work, start: start, end: start.addingTimeInterval(1800),
            ownerId: "u1", org: nil, visibility: "company", assignees: ["u2"], reminderMin: 0
        )
        #expect(payload.org == "")
        #expect(payload.visibility == "private")
        #expect(payload.assignee.isEmpty)
        #expect(payload.viewers.isEmpty)
    }

    /// Valkuil A: twee plekken maken afspraken aan, dus moeten ze exact dezelfde
    /// velden schrijven — alleen `source` en `raw_input` mogen verschillen.
    @Test func manualAndPlannerBranchWriteTheSameFieldsApartFromSourceAndRawInput() {
        let proposal = ProposedAppointment(
            title: "Kapper", date: "2026-08-03", start: "09:00", end: "09:30", category: .work
        )
        let range = AppointmentRange.range(for: proposal)
        let planner = AppointmentPayloadBuilder.build(
            appointment: proposal, ownerId: "u1", rawInput: "morgen 9 uur kapper", org: "org1",
            visibility: "company", viewers: [], assignees: ["u2"], reminderMin: 15,
            label: "l1", contact: "c1", contactNaam: "Jansen", contactTelefoon: "0612"
        )
        let manual = AppointmentPayloadBuilder.buildManual(
            title: "Kapper", category: .work, start: range.start, end: range.end,
            ownerId: "u1", org: "org1", visibility: "company", assignees: ["u2"], reminderMin: 15,
            label: "l1", contact: "c1", klantNaam: "Jansen", klantTelefoon: "0612"
        )

        let plannerBody = planner.requestBody
        let manualBody = manual.requestBody
        #expect(Set(plannerBody.keys) == Set(manualBody.keys))
        for key in plannerBody.keys where key != "source" && key != "raw_input" {
            #expect(
                String(describing: plannerBody[key]!) == String(describing: manualBody[key]!),
                "veld \(key) verschilt tussen de AI-tak en de handmatige tak"
            )
        }
    }

    @Test func startAndEndAreFormattedAsPocketBaseUtc() {
        let payload = AppointmentPayloadBuilder.build(
            appointment: appointment(), ownerId: "u1", rawInput: "raw", org: "org1",
            visibility: "private", viewers: [], assignees: [], reminderMin: 0
        )
        let body = payload.requestBody
        #expect((body["start"] as? String)?.hasSuffix("Z") == true)
        #expect((body["end"] as? String)?.hasSuffix("Z") == true)
    }
}
