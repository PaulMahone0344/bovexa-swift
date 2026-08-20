import Testing
import Foundation
@testable import Bovexa

/// AppointmentCreatePayload.source (M12 plak 1). Het veld is een verplichte
/// PB-select met exact twee waarden: 'nl' (AI-planner) en 'manual' (handmatig
/// formulier). Default blijft 'nl', zodat de planner ongewijzigd doorschrijft.
struct AppointmentCreatePayloadTests {
    private func payload(source: String? = nil) -> AppointmentCreatePayload {
        let start = Date(timeIntervalSince1970: 1_785_000_000)
        if let source {
            return AppointmentCreatePayload(
                owner: "u1", org: "org1", title: "Kapper", category: .work, calendar: "work",
                location: "", recurrence: "", klantNaam: "", klantTelefoon: "",
                start: start, end: start.addingTimeInterval(1800), visibility: "private",
                viewers: [], assignee: [], rawInput: "", reminderMin: 0, assigneeStatus: [:],
                source: source
            )
        }
        return AppointmentCreatePayload(
            owner: "u1", org: "org1", title: "Kapper", category: .work, calendar: "work",
            location: "", recurrence: "", klantNaam: "", klantTelefoon: "",
            start: start, end: start.addingTimeInterval(1800), visibility: "private",
            viewers: [], assignee: [], rawInput: "raw", reminderMin: 0, assigneeStatus: [:]
        )
    }

    @Test func sourceDefaultsToNl() {
        #expect(payload().source == "nl")
        #expect(payload().requestBody["source"] as? String == "nl")
    }

    @Test func manualSourceEndsUpInTheRequestBody() {
        #expect(payload(source: "manual").requestBody["source"] as? String == "manual")
    }

    /// Notitie hoort alleen in de body als er iets staat: de AI-tak zet 'm nooit,
    /// en beide takken moeten voor dezelfde invoer dezelfde body schrijven.
    @Test func notesAreOmittedWhenEmptyOrMissing() {
        #expect(payload().requestBody["notes"] == nil)
    }
}
