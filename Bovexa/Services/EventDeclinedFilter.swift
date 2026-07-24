extension Array where Element == AgendaEvent {
    /// Toewijzingen die je zelf geweigerd hebt horen niet meer in je agenda —
    /// eigen afspraken blijven altijd staan, ongeacht assignee_status.
    func excludingDeclined(for userId: String) -> [AgendaEvent] {
        filter { $0.owner == userId || $0.assigneeStatus[userId] != "declined" }
    }
}
