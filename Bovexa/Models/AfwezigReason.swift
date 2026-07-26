import Foundation

/// Reden-chips op het afwezig-scherm — geport uit LABELS in
/// ~/Desktop/agenda-app/src/app/afwezig.tsx.
enum AfwezigReason: String, CaseIterable, Identifiable {
    case vakantie = "Vakantie"
    case ziek = "Ziek"
    case vrij = "Vrij"
    /// Klantverzoek 26 juli: vrije toelichting, verplicht vóór doorgeven mogelijk is.
    case anders = "Anders"

    var id: String { rawValue }
    var label: String { rawValue }
}
