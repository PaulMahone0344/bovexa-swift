import Foundation

/// Wie wat mag met een team-dagtaak. De server beslist uiteindelijk (PB-rules op
/// agenda_tasks); dit houdt de knoppen in de app daarmee gelijk, zodat je niet op
/// iets kunt tikken dat daarna stilletjes terugdraait.
enum TaskPermissions {
    /// Afvinken mag de eigenaar, en iedereen die de gedeelde bedrijfstaak ziet: wie
    /// hem doet, vinkt hem af.
    static func canToggle(_ task: AgendaTask, userId: String) -> Bool {
        task.owner == userId || task.visibility == .company
    }

    /// Wissen blijft bij de eigenaar — niemand gooit het werk van een ander weg.
    static func canDelete(_ task: AgendaTask, userId: String) -> Bool {
        task.owner == userId
    }
}
