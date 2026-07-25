import Testing
@testable import Bovexa

struct MemberColorsTests {
    private func member(_ userId: String, naam: String = "", email: String = "test@bovexa.nl") -> Member {
        Member(id: userId, userId: userId, naam: naam, email: email, avatar: "")
    }

    @Test func primesColorsByIndexOnSortedUserIds() {
        // Sorteervolgorde van de userId's zelf bepaalt de index, niet de volgorde in de lijst.
        let colors = MemberColors()
        colors.prime(members: [member("zzz"), member("aaa"), member("mmm")])

        #expect(colors.colorHex(for: "aaa") == MemberColors.palette[0])
        #expect(colors.colorHex(for: "mmm") == MemberColors.palette[1])
        #expect(colors.colorHex(for: "zzz") == MemberColors.palette[2])
    }

    @Test func sameInputOrderIsStableAcrossPrimeCalls() {
        let a = MemberColors()
        a.prime(members: [member("u1"), member("u2")])
        let b = MemberColors()
        b.prime(members: [member("u2"), member("u1")])

        #expect(a.colorHex(for: "u1") == b.colorHex(for: "u1"))
        #expect(a.colorHex(for: "u2") == b.colorHex(for: "u2"))
    }

    @Test func unprimedUserIdFallsBackToDeterministicHash() {
        let colors = MemberColors()
        let first = colors.colorHex(for: "onbekend-id")
        let second = colors.colorHex(for: "onbekend-id")
        #expect(first == second)
        #expect(MemberColors.palette.contains(first))
    }

    @Test func nilUserIdReturnsFirstPaletteColor() {
        let colors = MemberColors()
        #expect(colors.colorHex(for: nil) == MemberColors.palette[0])
    }

    @Test func firstNameUsesNaamBeforeEmailFallback() {
        let colors = MemberColors()
        colors.prime(members: [member("u1", naam: "Ibrahim Khoulati"), member("u2", naam: "", email: "chafia@bovexa.nl")])

        #expect(colors.firstName(for: "u1") == "Ibrahim")
        #expect(colors.firstName(for: "u2") == "chafia")
        #expect(colors.firstName(for: "onbekend") == nil)
    }

    @Test func primeStoresOrgNameWhenProvided() {
        let colors = MemberColors()
        colors.prime(members: [member("u1")], org: CompanyOrgInfo(id: "org1", name: "Bovexa", logo: ""))
        #expect(colors.orgName == "Bovexa")
    }

    @Test func primeWithoutOrgLeavesOrgNameNil() {
        let colors = MemberColors()
        colors.prime(members: [member("u1")])
        #expect(colors.orgName == nil)
    }

    @Test func borderColorOnlyForOthersEvents() {
        let colors = MemberColors()
        colors.prime(members: [member("me"), member("collega")])

        #expect(colors.borderColorHex(owner: "collega", me: "me") == colors.colorHex(for: "collega"))
        #expect(colors.borderColorHex(owner: "me", me: "me") == nil)
        #expect(colors.borderColorHex(owner: nil, me: "me") == nil)
    }
}
