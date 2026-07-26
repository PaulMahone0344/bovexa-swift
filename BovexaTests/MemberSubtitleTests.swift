import Testing
import Foundation
@testable import Bovexa

/// Regel onder een collega in Mensen: rol, uitnodiging, en of jij het zelf bent.
struct MemberSubtitleTests {
    private func member(
        userId: String = "u2", role: CompanyRole = .member, status: String = "active", isOwner: Bool = false
    ) -> CompanyMember {
        CompanyMember(
            id: "m-\(userId)", userId: userId, naam: "Naam", email: "naam@bovexa.nl", avatar: "",
            role: role, status: status, isOwner: isOwner,
            magMaken: true, magWijzigen: true, magVerwijderen: false, magKlantZien: true, magAgendaAnderenZien: true
        )
    }

    @Test func plainMemberShowsRole() {
        #expect(MemberSubtitle.text(for: member(), currentUserId: "u1") == "Lid")
    }

    @Test func adminShowsBeheerder() {
        #expect(MemberSubtitle.text(for: member(role: .admin), currentUserId: "u1") == "Beheerder")
    }

    @Test func ownerBeatsRole() {
        let owner = member(role: .member, isOwner: true)
        #expect(MemberSubtitle.text(for: owner, currentUserId: "u1") == "Eigenaar")
    }

    @Test func yourselfIsMarked() {
        #expect(MemberSubtitle.text(for: member(userId: "u1"), currentUserId: "u1") == "Lid · jij")
    }

    @Test func invitedBeatsEverythingElse() {
        // Nog niet ingelogd: dan zegt "Lid" te veel, want er zit nog niemand achter.
        let invited = member(role: .admin, status: "invited")
        #expect(MemberSubtitle.text(for: invited, currentUserId: "u1") == "Uitgenodigd")
    }

    @Test func invitedYourselfStaysInvited() {
        let invited = member(userId: "u1", status: "invited")
        #expect(MemberSubtitle.text(for: invited, currentUserId: "u1") == "Uitgenodigd")
    }
}
