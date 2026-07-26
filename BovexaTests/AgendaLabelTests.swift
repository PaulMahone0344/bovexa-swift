import Testing
import Foundation
@testable import Bovexa

struct AgendaLabelTests {
    @Test func decodesFullPayload() throws {
        let json = """
        {"id":"l1","org":"org1","naam":"VSB","kleur":"#E08A3C","volgorde":2}
        """.data(using: .utf8)!
        let label = try JSONDecoder().decode(AgendaLabel.self, from: json)
        #expect(label.id == "l1")
        #expect(label.org == "org1")
        #expect(label.naam == "VSB")
        #expect(label.kleur == "#E08A3C")
        #expect(label.volgorde == 2)
    }

    @Test func missingVolgordeFallsBackToZero() throws {
        let json = """
        {"id":"l1","org":"org1","naam":"VSB","kleur":"#E08A3C"}
        """.data(using: .utf8)!
        let label = try JSONDecoder().decode(AgendaLabel.self, from: json)
        #expect(label.volgorde == 0)
    }
}
