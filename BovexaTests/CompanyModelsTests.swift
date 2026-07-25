import Testing
import Foundation
@testable import Bovexa

struct CompanyModelsTests {
    private func member(userId: String = "u2", isOwner: Bool = false) -> CompanyMember {
        CompanyMember(
            id: "m1", userId: userId, naam: "Anna", email: "anna@x.nl", avatar: "",
            role: .member, status: "active", isOwner: isOwner,
            magMaken: true, magWijzigen: false, magVerwijderen: false, magKlantZien: true, magAgendaAnderenZien: true
        )
    }

    // Valkuil C: bescherming zit al op modelniveau, vóórdat een viewmodel of view
    // ooit een knop toont.
    @Test func canBeManagedIsFalseForOwner() {
        #expect(member(isOwner: true).canBeManaged(by: "someone-else") == false)
    }

    @Test func canBeManagedIsFalseForSelf() {
        #expect(member(userId: "me").canBeManaged(by: "me") == false)
    }

    @Test func canBeManagedIsTrueForRegularOtherMember() {
        #expect(member(userId: "u2", isOwner: false).canBeManaged(by: "me") == true)
    }

    @Test func selectableRolesExcludeManager() {
        #expect(SelectableCompanyRole.allCases.map(\.role) == [.member, .admin])
    }

    @Test func displayNameFallsBackToEmail() {
        let m = CompanyMember(
            id: "m1", userId: "u1", naam: "", email: "anna@x.nl", avatar: "",
            role: .member, status: "active", isOwner: false,
            magMaken: false, magWijzigen: false, magVerwijderen: false, magKlantZien: false, magAgendaAnderenZien: false
        )
        #expect(m.displayName == "anna@x.nl")
    }

    @Test func openingHoursDecodesOnlySetDays() throws {
        let json = """
        {"mon": {"open": "09:00", "close": "17:00"}}
        """.data(using: .utf8)!
        let hours = try JSONDecoder().decode(OpeningHours.self, from: json)
        #expect(hours.mon?.open == "09:00")
        #expect(hours.tue == nil)
    }
}
