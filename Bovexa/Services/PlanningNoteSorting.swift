import Foundation

/// Sorteervolgorde voor dagtaken — geport uit sortPlanningNotes in planningNotes.ts: open
/// vóór afgevinkt, binnen elke groep nieuwste eerst. Archief-status telt hier niet mee;
/// het scherm filtert open/archief zelf uit de al-gesorteerde lijst.
enum PlanningNoteSorting {
    static func sort(_ notes: [PlanningNote]) -> [PlanningNote] {
        notes.sorted { a, b in
            if a.done != b.done { return !a.done }
            return a.createdAt > b.createdAt
        }
    }
}
