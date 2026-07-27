import Foundation

/// Welke lijst de Dagtaken-tab laat zien: je eigen dagtaken of die van het bedrijf.
/// Onthouden tussen sessies — wie vooral met de bedrijfslijst werkt, wil daar ook
/// weer beginnen in plaats van elke keer één tik verder te moeten.
enum DagtakenScope: String, CaseIterable {
    case mijn, bedrijf

    var label: String {
        switch self {
        case .mijn: return "Mijn"
        case .bedrijf: return "Bedrijf"
        }
    }
}

final class DagtakenScopePreference {
    private static let key = "bovexaflow_dagtaken_scope"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> DagtakenScope {
        guard let raw = defaults.string(forKey: Self.key), let scope = DagtakenScope(rawValue: raw) else {
            return .mijn
        }
        return scope
    }

    func save(_ scope: DagtakenScope) {
        defaults.set(scope.rawValue, forKey: Self.key)
    }
}
