import Testing
@testable import Bovexa

/// Geport uit sortMembers/filterMembers/toggleFavorite in ~/Desktop/agenda-app/src/lib/favorites.ts.
struct MemberSearchHelpersTests {
    private func member(_ userId: String, naam: String = "", email: String = "test@bovexa.nl") -> Member {
        Member(id: userId, userId: userId, naam: naam, email: email, avatar: "")
    }

    // MARK: - toggleFavorite

    @Test func toggleAddsUnfavoritedId() {
        let result = MemberSearchHelpers.toggleFavorite("u1", in: [])
        #expect(result == ["u1"])
    }

    @Test func toggleRemovesAlreadyFavoritedId() {
        let result = MemberSearchHelpers.toggleFavorite("u1", in: ["u1", "u2"])
        #expect(result == ["u2"])
    }

    // MARK: - sortMembers (favorieten eerst, dan alfabetisch)

    @Test func favoritesSortBeforeNonFavorites() {
        let members = [member("u1", naam: "Zara"), member("u2", naam: "Amir")]
        let sorted = MemberSearchHelpers.sortMembers(members, favorites: ["u1"])
        #expect(sorted.map(\.userId) == ["u1", "u2"])
    }

    @Test func nonFavoritesSortAlphabeticallyByName() {
        let members = [member("u1", naam: "Zara"), member("u2", naam: "Amir")]
        let sorted = MemberSearchHelpers.sortMembers(members, favorites: [])
        #expect(sorted.map(\.userId) == ["u2", "u1"])
    }

    @Test func missingNameFallsBackToEmailForSorting() {
        let members = [member("u1", naam: "", email: "zara@bovexa.nl"), member("u2", naam: "", email: "amir@bovexa.nl")]
        let sorted = MemberSearchHelpers.sortMembers(members, favorites: [])
        #expect(sorted.map(\.userId) == ["u2", "u1"])
    }

    @Test func multipleFavoritesStillSortAlphabeticallyAmongThemselves() {
        let members = [member("u1", naam: "Zara"), member("u2", naam: "Amir"), member("u3", naam: "Chafia")]
        let sorted = MemberSearchHelpers.sortMembers(members, favorites: ["u1", "u3"])
        #expect(sorted.map(\.userId) == ["u3", "u1", "u2"])
    }

    // MARK: - filterMembers (naam + e-mail, hoofdletterongevoelig)

    @Test func emptyQueryReturnsAllMembers() {
        let members = [member("u1", naam: "Amir")]
        #expect(MemberSearchHelpers.filterMembers(members, query: "  ") == members)
    }

    @Test func filterMatchesNameCaseInsensitively() {
        let members = [member("u1", naam: "Amir"), member("u2", naam: "Zara")]
        let result = MemberSearchHelpers.filterMembers(members, query: "AMIR")
        #expect(result.map(\.userId) == ["u1"])
    }

    @Test func filterMatchesEmailWhenNameDoesNotMatch() {
        let members = [member("u1", naam: "", email: "amir@bovexa.nl")]
        let result = MemberSearchHelpers.filterMembers(members, query: "bovexa")
        #expect(result.map(\.userId) == ["u1"])
    }

    @Test func filterWithNoMatchesReturnsEmpty() {
        let members = [member("u1", naam: "Amir")]
        #expect(MemberSearchHelpers.filterMembers(members, query: "onvindbaar").isEmpty)
    }
}
