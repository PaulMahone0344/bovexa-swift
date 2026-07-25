import Foundation

/// Eén regel in het planner-gesprek — geport uit ThreadItem in
/// ~/Desktop/agenda-app/src/hooks/useAiPlanner.ts. Daar is dit een discriminated union;
/// hier één vlakke, Codable struct (eenvoudiger te bewaren/laden), `kind` bepaalt welke
/// velden relevant zijn: user/error → alleen `text`, question → `text`+`options`,
/// proposal → `text`+`appointments`.
enum ThreadItemKind: String, Codable, Equatable {
    case user
    case question
    case proposal
    case error
}

struct ThreadItem: Identifiable, Codable, Equatable {
    let id: String
    let kind: ThreadItemKind
    let text: String
    var options: [String] = []
    var appointments: [ProposedAppointment] = []
}
