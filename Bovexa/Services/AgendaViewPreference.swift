import Foundation

/// Weergavekeuze agenda in UserDefaults — dagweergave wordt bewust nooit onthouden
/// (anders kom je na een dag-tik nooit meer automatisch in maandweergave terecht).
final class AgendaViewPreference {
    private static let key = "bovexaflow_agenda_view"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> AgendaViewKind {
        guard let raw = defaults.string(forKey: Self.key), let kind = AgendaViewKind(rawValue: raw) else {
            return .compact
        }
        return kind
    }

    func save(_ kind: AgendaViewKind) {
        guard kind != .dag else { return }
        defaults.set(kind.rawValue, forKey: Self.key)
    }
}
