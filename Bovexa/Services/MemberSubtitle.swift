import Foundation

/// Regel onder de naam van een collega in Mensen.
///
/// Stond eerst vast op "Toegewezen aan afspraken" — bij iedereen dezelfde tekst,
/// dus hij zei niets, en je stond er zelf tussen zonder dat te zien.
enum MemberSubtitle {
    static func text(for member: CompanyMember, currentUserId: String) -> String {
        if member.isInvited { return "Uitgenodigd" }
        let base = roleText(for: member)
        return member.userId == currentUserId ? "\(base) · jij" : base
    }

    private static func roleText(for member: CompanyMember) -> String {
        if member.isOwner { return "Eigenaar" }
        switch member.role {
        case .admin: return "Beheerder"
        // De rol Manager hoort bij de uitgezette werklaag en zou hier niet moeten
        // voorkomen; als hij tóch in de data staat, benoemen we hem eerlijk in
        // plaats van hem als gewoon lid te tonen.
        case .manager: return "Manager"
        case .member: return "Medewerker"
        }
    }
}
