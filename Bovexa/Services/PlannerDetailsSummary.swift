import Foundation

/// Eén regel die vertelt wat er in het dichtgeklapte detailblok van de planner
/// staat. Zonder die regel is inklappen een verstopactie: je moet openklappen om
/// te zien of de afspraak op privé staat of bij het bedrijf.
enum PlannerDetailsSummary {
    static func text(
        visibility: String?, companyName: String?, assigneeCount: Int,
        labelName: String?, contactName: String?, reminderMin: Int
    ) -> String {
        var parts: [String] = []

        if let visibility {
            parts.append(visibility == "private" ? "Privé" : (companyName ?? "Bedrijf"))
        }
        if assigneeCount > 0 {
            parts.append("Jij + \(assigneeCount)")
        }
        if let labelName, !labelName.isEmpty {
            parts.append(labelName)
        }
        if let contactName, !contactName.isEmpty {
            parts.append(contactName)
        }
        if reminderMin > 0 {
            parts.append(ReminderOption.label(for: reminderMin))
        }

        return parts.joined(separator: " · ")
    }
}
