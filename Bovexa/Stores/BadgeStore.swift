import Foundation

/// Cijfer op de Profiel-tab (M11 plak 6b, besluit Ibrahim 19 aug). Tot nu toe was
/// de 8pt-stip ín Profiel het enige signaal voor een openstaande toewijzing of een
/// ongelezen mededeling: vanuit Vandaag of Agenda zag je niets.
///
/// Bewust geen eigen netwerkverzoek. De cijfers komen uit loads die Vandaag,
/// Profiel en Meldingen toch al doen. Vandaag haalt bij het starten alle events
/// op, dus de badge klopt meteen — zonder dat zou hij pas verschijnen nadat je
/// Profiel een keer geopend hebt.
@MainActor
final class BadgeStore: ObservableObject {
    /// Toewijzingen die op jouw akkoord wachten en nog kunnen doorgaan. Verlopen
    /// toewijzingen tellen niet mee: daar is niets meer aan te doen, en anders
    /// blijft het cijfer eeuwig staan.
    @Published private(set) var pendingAssignments = 0
    @Published private(set) var unreadNotices = 0

    /// 0 = geen badge (SwiftUI verbergt `.badge(0)` zelf).
    var total: Int { pendingAssignments + unreadNotices }

    func setPendingAssignments(_ count: Int) {
        pendingAssignments = max(0, count)
    }

    func setUnreadNotices(_ count: Int) {
        unreadNotices = max(0, count)
    }

    /// Na accepteren, weigeren of het lezen van de mededelingen: het cijfer hoort
    /// meteen te kloppen, niet pas na de volgende load.
    func clearNotices() {
        unreadNotices = 0
    }
}
