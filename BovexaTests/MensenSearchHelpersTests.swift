import Testing
import Foundation
@testable import Bovexa

struct MensenSearchHelpersTests {
    private let contacts = [
        AgendaContact(id: "c1", eigenaar: "u1", naam: "Karim", telefoon: "0611111111", notitie: ""),
        AgendaContact(id: "c2", eigenaar: "u1", naam: "Sanae", telefoon: "0622222222", notitie: ""),
    ]

    private let members = [
        CompanyMember(
            id: "m1", userId: "u2", naam: "Yassine", email: "yassine@bovexa.nl", avatar: "",
            role: .member, status: "active", isOwner: false,
            magMaken: true, magWijzigen: true, magVerwijderen: false, magKlantZien: true, magAgendaAnderenZien: true
        ),
        CompanyMember(
            id: "m2", userId: "u3", naam: "Fatima", email: "fatima@bovexa.nl", avatar: "",
            role: .member, status: "active", isOwner: false,
            magMaken: true, magWijzigen: true, magVerwijderen: false, magKlantZien: true, magAgendaAnderenZien: true
        ),
    ]

    @Test func emptyQueryReturnsAllContacts() {
        #expect(MensenSearchHelpers.filterContacts(contacts, query: "").map(\.id) == ["c1", "c2"])
    }

    @Test func queryFiltersContactsByNaam() {
        #expect(MensenSearchHelpers.filterContacts(contacts, query: "kar").map(\.id) == ["c1"])
    }

    @Test func queryFiltersMembersByNaam() {
        #expect(MensenSearchHelpers.filterMembers(members, query: "yas").map(\.id) == ["m1"])
    }

    @Test func queryFiltersBothSectionsSimultaneously() {
        let filteredContacts = MensenSearchHelpers.filterContacts(contacts, query: "sa")
        let filteredMembers = MensenSearchHelpers.filterMembers(members, query: "sa")
        #expect(filteredContacts.map(\.id) == ["c2"])
        #expect(filteredMembers.isEmpty)
    }

    @Test func nonMatchingQueryReturnsEmpty() {
        #expect(MensenSearchHelpers.filterContacts(contacts, query: "zzz").isEmpty)
        #expect(MensenSearchHelpers.filterMembers(members, query: "zzz").isEmpty)
    }
}
