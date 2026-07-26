import Testing
import Foundation
@testable import Bovexa

/// m10 plak 3: wie het recht mag_agenda_anderen_zien niet heeft, hoort de kiezer
/// niet te krijgen. Dat is geen beveiliging — de server bepaalt al wat je
/// binnenhaalt — maar een lijst met namen aanbieden die je daarna niet kunt
/// bekijken is misleidend.
@MainActor
struct AgendaPersonFilterAccessTests {
    private func member(
        userId: String, role: CompanyRole? = .member, maySeeOthers: Bool = false
    ) -> Member {
        Member(
            id: "m-\(userId)", userId: userId, naam: "Naam \(userId)", email: "\(userId)@x.nl",
            avatar: "", role: role, magAgendaAnderenZien: maySeeOthers
        )
    }

    private func colors(_ members: [Member]) -> MemberColors {
        let store = MemberColors()
        store.prime(members: members)
        return store
    }

    @Test("Met het recht mag de kiezer verschijnen")
    func withPermissionAllowed() {
        let store = colors([member(userId: "u1", maySeeOthers: true)])
        #expect(AgendaPersonFilterAccess.isAllowed(userId: "u1", members: store.members))
    }

    @Test("Zonder het recht niet")
    func withoutPermissionDenied() {
        let store = colors([member(userId: "u1", maySeeOthers: false)])
        #expect(!AgendaPersonFilterAccess.isAllowed(userId: "u1", members: store.members))
    }

    /// Een admin beheert de rechten van anderen; die zichzelf buitensluiten van de
    /// agenda van zijn team zou onlogisch zijn, en hij kan het vinkje toch zetten.
    @Test("Een admin mag het altijd, ook zonder het losse vinkje")
    func adminAlwaysAllowed() {
        let store = colors([member(userId: "u1", role: .admin, maySeeOthers: false)])
        #expect(AgendaPersonFilterAccess.isAllowed(userId: "u1", members: store.members))
    }

    @Test("Het recht van een collega geeft jou niets")
    func otherMembersPermissionIrrelevant() {
        let store = colors([
            member(userId: "u1", maySeeOthers: false),
            member(userId: "u2", maySeeOthers: true),
        ])
        #expect(!AgendaPersonFilterAccess.isAllowed(userId: "u1", members: store.members))
    }

    /// Zolang de ledenlijst nog niet binnen is weten we het niet; dan liever geen
    /// knop dan een knop die daarna verdwijnt.
    @Test("Nog geen ledenlijst betekent geen kiezer")
    func unknownMembershipDenied() {
        #expect(!AgendaPersonFilterAccess.isAllowed(userId: "u1", members: []))
    }
}
