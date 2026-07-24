enum AgendaViewKind: String, CaseIterable {
    case dag, compact, gestapeld, details, lijst

    var label: String {
        switch self {
        case .dag: return "Dag"
        case .compact: return "Compact"
        case .gestapeld: return "Gestapeld"
        case .details: return "Details"
        case .lijst: return "Lijst"
        }
    }

    var isMonthView: Bool {
        self == .compact || self == .gestapeld || self == .details
    }
}
