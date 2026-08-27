extension Array where Element == AgendaEvent {
    /// Toewijzingen die je zelf geweigerd hebt horen niet meer in je agenda —
    /// eigen afspraken blijven altijd staan, ongeacht assignee_status.
    func excludingDeclined(for userId: String) -> [AgendaEvent] {
        filter { $0.owner == userId || $0.assigneeStatus[userId] != "declined" }
    }

    /// Wat er in jouw agenda hoort te staan. Een afspraak die iemand naar je
    /// toestuurt is een verzoek, geen feit: die staat bij Meldingen en verhuist
    /// pas naar de agenda zodra je hem accepteert. Eerder stond hij er meteen in
    /// en kon je hem achteraf wegklikken — dan blokkeert andermans verzoek je dag
    /// terwijl je nog niets gezegd hebt.
    ///
    /// Afspraken die je alleen mag meekijken (viewers, zonder toewijzing) vallen
    /// hier buiten: daar wordt niets van je gevraagd, dus die blijven staan.
    func onlyAccepted(for userId: String) -> [AgendaEvent] {
        filter { event in
            if event.owner == userId { return true }
            guard event.assignee.contains(userId) else { return true }
            return event.assigneeStatus[userId] == "accepted"
        }
    }
}
