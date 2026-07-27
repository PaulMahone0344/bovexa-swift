import Testing
import Foundation
@testable import Bovexa

struct DagtakenScopePreferenceTests {
    private func makeDefaults() -> UserDefaults {
        let suiteName = "bovexa-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    /// Zonder eerdere keuze begin je bij je eigen lijst: die is van jou alleen en
    /// staat er ook als er geen bedrijf aan hangt.
    @Test func defaultsToYourOwnList() {
        let preference = DagtakenScopePreference(defaults: makeDefaults())

        #expect(preference.load() == .mijn)
    }

    @Test func remembersTheLastChoice() {
        let defaults = makeDefaults()
        DagtakenScopePreference(defaults: defaults).save(.bedrijf)

        #expect(DagtakenScopePreference(defaults: defaults).load() == .bedrijf)
    }

    /// Onzin in de opslag (oude versie, handmatig geknoei) mag geen leeg scherm
    /// geven — dan gewoon terug naar de eigen lijst.
    @Test func unknownStoredValueFallsBack() {
        let defaults = makeDefaults()
        defaults.set("weekoverzicht", forKey: "bovexaflow_dagtaken_scope")

        #expect(DagtakenScopePreference(defaults: defaults).load() == .mijn)
    }
}
