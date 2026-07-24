import Testing
import Foundation
@testable import Bovexa

struct AgendaUserDecodingTests {
    @Test func decodeWithDefaultOrg() throws {
        let json = """
        {"id":"u1","email":"a@b.nl","naam":"Ibrahim","avatar":"foto.jpg","default_org":"org1"}
        """.data(using: .utf8)!
        let user = try JSONDecoder().decode(AgendaUser.self, from: json)
        #expect(user.id == "u1")
        #expect(user.email == "a@b.nl")
        #expect(user.naam == "Ibrahim")
        #expect(user.defaultOrg == "org1")
    }

    @Test func decodeWithEmptyDefaultOrgIsNil() throws {
        let json = """
        {"id":"u1","email":"a@b.nl","naam":"Ibrahim","avatar":"","default_org":""}
        """.data(using: .utf8)!
        let user = try JSONDecoder().decode(AgendaUser.self, from: json)
        #expect(user.defaultOrg == nil)
    }

    @Test func decodeWithoutNaamOrDefaultOrgDoesNotCrash() throws {
        let json = """
        {"id":"u1","email":"a@b.nl"}
        """.data(using: .utf8)!
        let user = try JSONDecoder().decode(AgendaUser.self, from: json)
        #expect(user.naam == nil)
        #expect(user.defaultOrg == nil)
    }
}
