import Foundation

/// Toewijzings-logica (valkuil B) — geport uit ~/Desktop/agenda-app/src/lib/assignments.ts.
/// assignee_status staat als json-map op het event: userId → "pending" | "accepted" | "declined".
enum AssignmentHelpers {
    /// Nieuwe assignee_status-map voor een nieuwe/gewijzigde toewijzing: de eigenaar
    /// die zichzelf toewijst hoeft niets te accepteren, de rest komt op "pending" tenzij
    /// er al een antwoord stond. Wie eraf gehaald is verdwijnt uit de map.
    static func nextStatusMap(assignees: [String], ownerId: String, previous: [String: String] = [:]) -> [String: String] {
        var next: [String: String] = [:]
        for id in assignees {
            next[id] = id == ownerId ? "accepted" : (previous[id] ?? "pending")
        }
        return next
    }

    /// Status van één persoon. nil = niet toegewezen. Ontbrekende sleutel = "pending".
    static func assignmentStatus(assignees: [String], statusMap: [String: String], userId: String) -> String? {
        guard assignees.contains(userId) else { return nil }
        return statusMap[userId] ?? "pending"
    }

    /// Aantal toewijzingen dat op jouw akkoord wacht (m6, Profiel-teller/-stip).
    /// Verlopen toewijzingen tellen niet mee, anders blijft de stip eeuwig branden.
    static func pendingCount(_ events: [AgendaEvent], userId: String, now: Date = Date()) -> Int {
        pendingEvents(events, userId: userId, now: now).count
    }

    /// Afspraken die op jouw akkoord wachten en nog kunnen doorgaan, nieuwste eerst
    /// (m6, Meldingen-scherm). Sluit je eigen afspraken uit — als eigenaar sta je al
    /// op "accepted" (zie nextStatusMap).
    static func pendingEvents(_ events: [AgendaEvent], userId: String, now: Date = Date()) -> [AgendaEvent] {
        awaitingReply(events, userId: userId)
            .filter { !hasPassed($0, now: now) }
            .sorted { $0.start > $1.start }
    }

    /// Toewijzingen waar je nooit op geantwoord hebt en waarvan de afspraak al
    /// voorbij is. Accepteren of weigeren zegt daar niets meer, maar weggooien ook
    /// niet: dan weet je nooit dat er iets langs is gekomen. Meldingen zet ze apart.
    static func expiredPendingEvents(_ events: [AgendaEvent], userId: String, now: Date = Date()) -> [AgendaEvent] {
        awaitingReply(events, userId: userId)
            .filter { hasPassed($0, now: now) }
            .sorted { $0.start > $1.start }
    }

    private static func awaitingReply(_ events: [AgendaEvent], userId: String) -> [AgendaEvent] {
        events.filter {
            $0.owner != userId
                && assignmentStatus(assignees: $0.assignee, statusMap: $0.assigneeStatus, userId: userId) == "pending"
        }
    }

    /// Met eindtijd: voorbij zodra die eindtijd geweest is, dus een afspraak die nu
    /// loopt telt nog mee. Zonder eindtijd loopt hij tot het eind van zijn dag —
    /// een toewijzing voor vandaag 09:00 moet je om 11:30 nog kunnen beantwoorden,
    /// en op de starttijd terugvallen zou hem meteen als verlopen bestempelen.
    private static func hasPassed(_ event: AgendaEvent, now: Date, calendar: Calendar = .current) -> Bool {
        if let end = event.end { return end < now }
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: event.start)) else {
            return event.start < now
        }
        return endOfDay <= now
    }
}
