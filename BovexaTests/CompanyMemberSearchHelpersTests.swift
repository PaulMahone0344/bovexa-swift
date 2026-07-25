import Testing
@testable import Bovexa

struct CompanyMemberSearchHelpersTests {
    private func member(id: String, userId: String, naam: String, email: String, isOwner: Bool = false) -> CompanyMember {
        CompanyMember(
            id: id, userId: userId, naam: naam, email: email, avatar: "",
            role: .member, status: "active", isOwner: isOwner,
            magMaken: false, magWijzigen: false, magVerwijderen: false, magKlantZien: false, magAgendaAnderenZien: false
        )
    }

    @Test func filterMembersMatchesNaamOrEmail() {
        let members = [
            member(id: "1", userId: "u1", naam: "Anna Bakker", email: "anna@x.nl"),
            member(id: "2", userId: "u2", naam: "Bram", email: "bram@voorbeeld.nl"),
        ]
        let result = CompanyMemberSearchHelpers.filterMembers(members, query: "bakker")
        #expect(result.map(\.userId) == ["u1"])

        let byEmail = CompanyMemberSearchHelpers.filterMembers(members, query: "voorbeeld")
        #expect(byEmail.map(\.userId) == ["u2"])
    }

    @Test func filterMembersEmptyQueryReturnsAll() {
        let members = [member(id: "1", userId: "u1", naam: "Anna", email: "anna@x.nl")]
        #expect(CompanyMemberSearchHelpers.filterMembers(members, query: "  ").count == 1)
    }

    @Test func sortMembersPutsFavoritesFirstThenAlphabetical() {
        let members = [
            member(id: "1", userId: "u1", naam: "Zara", email: "zara@x.nl"),
            member(id: "2", userId: "u2", naam: "Anna", email: "anna@x.nl"),
            member(id: "3", userId: "u3", naam: "Mo", email: "mo@x.nl"),
        ]
        let sorted = CompanyMemberSearchHelpers.sortMembers(members, favorites: ["u1"])
        #expect(sorted.map(\.userId) == ["u1", "u2", "u3"])
    }

    @Test func sortMembersFallsBackToAlphabeticalWithoutFavorites() {
        let members = [
            member(id: "1", userId: "u1", naam: "Zara", email: "zara@x.nl"),
            member(id: "2", userId: "u2", naam: "Anna", email: "anna@x.nl"),
        ]
        let sorted = CompanyMemberSearchHelpers.sortMembers(members, favorites: [])
        #expect(sorted.map(\.userId) == ["u2", "u1"])
    }

    @Test func toggleFavoriteAddsThenRemoves() {
        let added = CompanyMemberSearchHelpers.toggleFavorite("u1", in: [])
        #expect(added == ["u1"])
        let removed = CompanyMemberSearchHelpers.toggleFavorite("u1", in: added)
        #expect(removed.isEmpty)
    }
}
