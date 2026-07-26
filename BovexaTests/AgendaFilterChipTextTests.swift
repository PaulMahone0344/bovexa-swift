import Testing
import Foundation
@testable import Bovexa

/// Chip boven de Agenda: hij verschijnt alleen als je meer ziet dan je eigen dag.
struct AgendaFilterChipTextTests {
    @Test func noChipWhenOnlyYourself() {
        #expect(AgendaFilterChipText.text(extraNames: []) == nil)
    }

    @Test func oneColleagueIsNamed() {
        #expect(AgendaFilterChipText.text(extraNames: ["Daan"]) == "Jij + Daan")
    }

    @Test func twoColleaguesAreBothNamed() {
        #expect(AgendaFilterChipText.text(extraNames: ["Nora", "Daan"]) == "Jij + Daan en Nora")
    }

    /// Vanaf drie namen wordt de chip breder dan een telefoon, dus dan telt hij.
    @Test func threeOrMoreAreCounted() {
        #expect(AgendaFilterChipText.text(extraNames: ["Daan", "Nora", "Emma"]) == "Jij + 3 collega's")
    }

    @Test func emptyNamesAreIgnored() {
        #expect(AgendaFilterChipText.text(extraNames: ["", "Daan"]) == "Jij + Daan")
        #expect(AgendaFilterChipText.text(extraNames: ["", ""]) == nil)
    }
}
