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

    /// Is deze bedrijfstaak aan jou gericht? Je eigen taken, taken waar je bij de
    /// toegewezen personen staat, en taken zonder toewijzing (die zijn voor het
    /// hele team). Een taak die aan een collega is gegeven hoort niet in jouw lijst.
    static func isGerichtAan(_ userId: String, task: AgendaTask) -> Bool {
        if task.owner == userId { return true }
        let toegewezen = task.viewers.filter { $0 != task.owner }
        return toegewezen.isEmpty || toegewezen.contains(userId)
    }

    /// Wissen blijft bij de eigenaar — niemand gooit het werk van een ander weg.
    static func canDelete(_ task: AgendaTask, userId: String) -> Bool {
        task.owner == userId
    }

    /// Bewerken volgt wissen: de tekst van een ander herschrijven is net zo
    /// ingrijpend als hem weggooien.
    static func canEdit(_ task: AgendaTask, userId: String) -> Bool {
        task.owner == userId
    }
}
