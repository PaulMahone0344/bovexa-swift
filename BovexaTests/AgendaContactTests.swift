import Testing
import Foundation
@testable import Bovexa

struct AgendaContactTests {
    @Test func decodesFullPayload() throws {
        let json = """
        {"id":"c1","eigenaar":"u1","naam":"Karim","telefoon":"0612345678","notitie":"buurman"}
        """.data(using: .utf8)!
        let contact = try JSONDecoder().decode(AgendaContact.self, from: json)
        #expect(contact.id == "c1")
        #expect(contact.eigenaar == "u1")
        #expect(contact.naam == "Karim")
        #expect(contact.telefoon == "0612345678")
        #expect(contact.notitie == "buurman")
    }

    @Test func missingOptionalFieldsFallBackToEmptyString() throws {
        let json = """
        {"id":"c1","eigenaar":"u1","naam":"Karim"}
        """.data(using: .utf8)!
        let contact = try JSONDecoder().decode(AgendaContact.self, from: json)
        #expect(contact.telefoon == "")
        #expect(contact.notitie == "")
    }
}
