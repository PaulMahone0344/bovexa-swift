import Testing
import Foundation
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

    // MARK: - standaardduur (M12): komt mee in dezelfde ledenlijst

    @Test func primeStoresCompanyDefaultDuration() {
        let colors = MemberColors()
        colors.prime(members: [member("u1")], org: CompanyOrgInfo(id: "org1", name: "Bovexa", logo: "", defaultDurationMin: 45))
        #expect(colors.orgDefaultDurationMin == 45)
    }

    /// 0 betekent op de server "niet ingesteld" (zie TeambeheerViewModel) — dan moet
    /// het formulier zijn eigen terugval gebruiken, niet een afspraak van nul minuten.
    @Test func zeroOrMissingDefaultDurationStaysNil() {
        let zero = MemberColors()
        zero.prime(members: [member("u1")], org: CompanyOrgInfo(id: "org1", name: "Bovexa", logo: "", defaultDurationMin: 0))
        #expect(zero.orgDefaultDurationMin == nil)

        let none = MemberColors()
        none.prime(members: [member("u1")], org: CompanyOrgInfo(id: "org1", name: "Bovexa", logo: ""))
        #expect(none.orgDefaultDurationMin == nil)
    }

    /// De ledenlijst wordt bij elke tabwissel opnieuw geprimed; een respons zonder
    /// duur mag een eerder gevonden waarde niet wissen (dan zou de duur heen en weer
    /// springen tussen 45 en de terugval).
    @Test func primeWithoutDurationKeepsAPreviouslyFoundOne() {
        let colors = MemberColors()
        colors.prime(members: [member("u1")], org: CompanyOrgInfo(id: "org1", name: "Bovexa", logo: "", defaultDurationMin: 45))
        colors.prime(members: [member("u1")], org: CompanyOrgInfo(id: "org1", name: "Bovexa", logo: ""))
        #expect(colors.orgDefaultDurationMin == 45)
    }

    @Test func orgInfoDecodesDefaultDurationFromTheMembersResponse() throws {
        let json = Data("""
        {"items":[],"org":{"id":"org1","name":"Bovexa","logo":"","default_duration_min":45}}
        """.utf8)
        let response = try JSONDecoder().decode(MembersResponse.self, from: json)
        #expect(response.org?.defaultDurationMin == 45)
    }

    /// Ontbreekt het veld of komt het als tekst binnen, dan mag de hele ledenlijst
    /// niet omvallen — zelfde defensieve lijn als AgendaEvent/Member.
    @Test func orgInfoSurvivesAMissingOrWronglyTypedDuration() throws {
        let missing = Data("""
        {"items":[],"org":{"id":"org1","name":"Bovexa","logo":""}}
        """.utf8)
        #expect(try JSONDecoder().decode(MembersResponse.self, from: missing).org?.defaultDurationMin == nil)

        let wrongType = Data("""
        {"items":[],"org":{"id":"org1","name":"Bovexa","logo":"","default_duration_min":"45"}}
        """.utf8)
        #expect(try JSONDecoder().decode(MembersResponse.self, from: wrongType).org?.defaultDurationMin == nil)
    }

    @Test func borderColorOnlyForOthersEvents() {
        let colors = MemberColors()
        colors.prime(members: [member("me"), member("collega")])

        #expect(colors.borderColorHex(owner: "collega", me: "me") == colors.colorHex(for: "collega"))
        #expect(colors.borderColorHex(owner: "me", me: "me") == nil)
        #expect(colors.borderColorHex(owner: nil, me: "me") == nil)
    }
}

/// De members-route stuurt `magAgendaAnderenZien` in camelCase; tot 7 sep 2026
/// las het model alleen `mag_agenda_anderen_zien` en stond het recht daardoor
/// voor elke medewerker op false.
struct MemberDecodingTests {
    private func decode(_ json: String) throws -> Member {
        try JSONDecoder().decode(Member.self, from: Data(json.utf8))
    }

    @Test func readsCamelCaseRightFromMembersRoute() throws {
        let m = try decode(#"{"id":"m1","userId":"u1","naam":"Ayman","email":"a@b.nl","avatar":"","role":"member","magAgendaAnderenZien":true}"#)
        #expect(m.magAgendaAnderenZien == true)
    }

    @Test func stillReadsSnakeCaseAsFallback() throws {
        let m = try decode(#"{"id":"m1","userId":"u1","naam":"Ayman","email":"a@b.nl","avatar":"","mag_agenda_anderen_zien":true}"#)
        #expect(m.magAgendaAnderenZien == true)
    }

    @Test func missingRightMeansFalse() throws {
        let m = try decode(#"{"id":"m1","userId":"u1","naam":"Ayman","email":"a@b.nl","avatar":""}"#)
        #expect(m.magAgendaAnderenZien == false)
    }
}
