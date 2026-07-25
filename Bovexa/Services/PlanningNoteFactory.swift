import Foundation

/// Bouwt een PlanningNote uit vrije tekst — geport uit makePlanningNote/updatePlanningNote
/// in ~/Desktop/agenda-app/src/lib/planningNotes.ts (valkuil B). De composer is één
/// tekstveld: de eerste niet-lege regel wordt de titel (witruimte samengeknepen), de
/// overige niet-lege regels worden de tekst. Lege of alleen-witruimte-invoer geeft nil.
enum PlanningNoteFactory {
    static func make(text: String, id: String = UUID().uuidString, createdAt: Date = Date()) -> PlanningNote? {
        guard let draft = parse(text) else { return nil }
        return PlanningNote(id: id, title: draft.title, body: draft.body, done: false, createdAt: createdAt, updatedAt: createdAt, archived: false)
    }

    static func update(_ note: PlanningNote, text: String, updatedAt: Date = Date()) -> PlanningNote? {
        guard let draft = parse(text) else { return nil }
        return PlanningNote(id: note.id, title: draft.title, body: draft.body, done: note.done, createdAt: note.createdAt, updatedAt: updatedAt, archived: note.archived)
    }

    /// Tekst voor de composer bij "Bewerken" — titel + tekst weer op losse regels.
    static func draftText(for note: PlanningNote) -> String {
        [note.title, note.body].filter { !$0.isEmpty }.joined(separator: "\n")
    }

    /// Zelfde titel/body-splitsing, herbruikt door DagtakenViewModel voor de
    /// team-aanmaak-tak (agenda_tasks heeft geen PlanningNote, wel dezelfde composer).
    static func parse(_ text: String) -> (title: String, body: String)? {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let title = normalizeTitle(lines.first ?? "")
        guard !title.isEmpty else { return nil }
        return (title, lines.dropFirst().joined(separator: "\n"))
    }

    private static func normalizeTitle(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }
}
