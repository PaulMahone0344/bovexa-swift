import Testing
import Foundation
@testable import Bovexa

struct AgendaViewPreferenceTests {
    private func makeDefaults() -> UserDefaults {
        let suiteName = "bovexa-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @Test func defaultsToCompactWhenNothingStored() {
        let preference = AgendaViewPreference(defaults: makeDefaults())
        #expect(preference.load() == .compact)
    }

    @Test func savesAndReloadsNonDagKind() {
        let defaults = makeDefaults()
        let preference = AgendaViewPreference(defaults: defaults)
        preference.save(.lijst)
        #expect(AgendaViewPreference(defaults: defaults).load() == .lijst)
    }

    @Test func neverPersistsDagWeergave() {
        // Dagweergave is bewust niet onthouden — anders kom je na een dag-tik nooit
        // meer automatisch in maandweergave terecht.
        let defaults = makeDefaults()
        let preference = AgendaViewPreference(defaults: defaults)
        preference.save(.details)
        preference.save(.dag)
        #expect(AgendaViewPreference(defaults: defaults).load() == .details)
    }
}
