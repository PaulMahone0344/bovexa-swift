import Foundation

/// Bewaarde staat van een AI-gesprek — thread voor de UI, api-historie voor de
/// volgende requestPlan()-aanroep, raw = eerste user-tekst (voor raw_input-audit).
struct SavedConversation: Codable, Equatable {
    let thread: [ThreadItem]
    let api: [ChatTurn]
    let raw: String
}

/// AI-gesprek per gebruiker — lokaal op het toestel, zelfde sleutelgedrag als de
/// RN-app: bovexaflow_ai_thread_<userId>. Getrimd op maxima (valkuil F) bij het
/// bewaren, zodat de opslag niet ongelimiteerd groeit.
final class PlannerThreadStore {
    private static let keyPrefix = "bovexaflow_ai_thread_"
    static let maxThreadItems = 40
    static let maxApiTurns = 30

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private func key(userId: String) -> String {
        Self.keyPrefix + userId
    }

    func load(userId: String) -> SavedConversation? {
        guard let data = defaults.data(forKey: key(userId: userId)) else { return nil }
        return try? JSONDecoder().decode(SavedConversation.self, from: data)
    }

    func save(_ conversation: SavedConversation, userId: String) {
        let trimmed = SavedConversation(
            thread: Array(conversation.thread.suffix(Self.maxThreadItems)),
            api: Array(conversation.api.suffix(Self.maxApiTurns)),
            raw: conversation.raw
        )
        guard let data = try? JSONEncoder().encode(trimmed) else { return }
        defaults.set(data, forKey: key(userId: userId))
    }

    func clear(userId: String) {
        defaults.removeObject(forKey: key(userId: userId))
    }
}
