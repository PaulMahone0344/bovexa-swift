import Foundation

/// Viewmodel voor de Bedrijf-tab: zonder bedrijf (starten/toetreden) én met bedrijf
/// (bedrijfskaart, ledenlijst, rol/rechten-beheer). Eén viewmodel voor beide staten,
/// zoals de RN Bedrijf()-component ook één scherm is met een EmptyOrg-substaat.
@MainActor
final class BedrijfViewModel: ObservableObject {
    enum EmptyMode {
        case choice
        case name
        case code
        /// Aanvraag om aan een bestaand bedrijf gekoppeld te worden. Sinds
        /// 25 augustus de bovenste weg voor een nieuw account: zelf een bedrijf
        /// starten hoort bij de beheerder, niet bij iedereen die zich aanmeldt.
        case aanvraag
    }

    @Published var emptyMode: EmptyMode = .choice
    @Published var nameDraft = ""
    @Published var codeDraft = ""
    /// Bedrijfsnaam in de koppelingsaanvraag; de beheerder moet weten om welk
    /// bedrijf het gaat.
    @Published var aanvraagNaam = ""
    /// Vrije toelichting ("ik ben trainer bij de O13") — mag leeg blijven.
    @Published var aanvraagToelichting = ""
    /// Blijft op het toestel staan zodra de aanvraag geslaagd verstuurd is, zodat
    /// het scherm na een herstart niet opnieuw om dezelfde aanvraag vraagt.
    @Published private(set) var aanvraagVerstuurdVoor: String?
    @Published private(set) var busy = false
    @Published var errorMessage: String?

    /// Optimistisch gezet zodra create/join lukt — de view schakelt hierop meteen
    /// door naar de bedrijfsstaat, vooruitlopend op AuthStore.refreshCurrentUser().
    @Published private(set) var justJoined = false

    @Published private(set) var loading = false
    @Published private(set) var refreshing = false
    @Published private(set) var membersResponse: CompanyMembersResponse?

    @Published private(set) var favorites: [String] = []
    @Published var memberQuery = ""

    /// Uitgeklapte rij in de ledenlijst (rol/rechten/verwijderen, plak 4).
    @Published var expandedMemberId: String?
    @Published private(set) var busyMemberId: String?
    @Published var memberActionErrorMessage: String?
    /// Aan als de laatste ledenlijst-fetch mislukte; de vorige blijft staan.
    @Published private(set) var loadFailed = false

    /// Alle bedrijven van dit account (company/mine). Meer dan één → de view
    /// toont de wisselrij. Valt de route weg, dan blijft de laatst bekende
    /// lijst staan via BekendeBedrijvenStore.
    @Published private(set) var mijnBedrijven: [OrgSummary] = []
    /// Org-id waar op dit moment naartoe gewisseld wordt (spinner op die chip).
    @Published private(set) var wisselBezigOrgId: String?

    let memberColors = MemberColors()

    /// Mensen die bij het bedrijf horen maar geen account hebben — onder Mensen
    /// aan het bedrijf gekoppeld. Ze staan bij het team, want ze horen erbij, maar
    /// ze kunnen niets in de app.
    @Published private(set) var bedrijfsContacten: [AgendaContact] = []

    private let repository: CompanyRepository
    private let favoritesStore: FavoritesStore
    private let aanvraagStore: BedrijfAanvraagStore
    private let contactRepository: ContactRepository

    init(
        repository: CompanyRepository = CompanyRepository(),
        favoritesStore: FavoritesStore = FavoritesStore(),
        aanvraagStore: BedrijfAanvraagStore = BedrijfAanvraagStore(),
        contactRepository: ContactRepository = ContactRepository()
    ) {
        self.contactRepository = contactRepository
        self.repository = repository
        self.favoritesStore = favoritesStore
        self.aanvraagStore = aanvraagStore
    }

    var hasLoadedCompany: Bool { membersResponse != nil }
    var members: [CompanyMember] { membersResponse?.items ?? [] }
    var org: CompanyOrgProfile? { membersResponse?.org }
    var seatsMax: Int? { membersResponse?.seatsMax }
    var joinCode: String? { membersResponse?.joinCode }

    /// Regel op de bedrijfskaart. seats_max 0 betekent onbeperkt (zelfde afspraak
    /// als TeambeheerViewModel.full), dus dan geen "2 van 0 accounts" tonen.
    /// Het gaat om accounts, niet om mensen: wie geen inlog heeft telt niet mee
    /// tegen de limiet van het plan. Vandaar "2 van 3 accounts" bij vier leden.
    var seatsText: String? {
        guard let seatsMax, seatsMax > 0 else { return nil }
        return "\(members.count) van \(seatsMax) accounts"
    }

    /// Favorieten bovenaan, daarna alfabetisch; zoekbalk verschijnt vanaf 6 leden
    /// (view beslist, dit is puur de gefilterde/gesorteerde data).
    var visibleMembers: [CompanyMember] {
        CompanyMemberSearchHelpers.sortMembers(CompanyMemberSearchHelpers.filterMembers(members, query: memberQuery), favorites: favorites)
    }

    func isFavorite(_ userId: String) -> Bool { favorites.contains(userId) }

    func toggleFavorite(_ memberUserId: String, currentUserId: String) {
        favorites = CompanyMemberSearchHelpers.toggleFavorite(memberUserId, in: favorites)
        favoritesStore.save(favorites, userId: currentUserId)
    }

    func role(for userId: String) -> CompanyRole? {
        members.first { $0.userId == userId }?.role
    }

    func isAdmin(_ userId: String) -> Bool {
        role(for: userId) == .admin
    }

    var canCreate: Bool { !nameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !busy }
    var canRequest: Bool { aanvraagNaam.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 && !busy }
    var canJoin: Bool { !codeDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !busy }

    func openMode(_ mode: EmptyMode) {
        errorMessage = nil
        emptyMode = mode
    }

    @discardableResult
    func createCompany(token: String) async -> Bool {
        let trimmed = nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            errorMessage = "Vul een bedrijfsnaam in (min. 2 tekens)."
            return false
        }
        errorMessage = nil
        busy = true
        defer { busy = false }
        do {
            _ = try await repository.createCompany(name: trimmed, token: token)
            justJoined = true
            return true
        } catch {
            errorMessage = Self.errorText(error, fallback: "Bedrijf aanmaken mislukt.")
            return false
        }
    }

    /// Verstuurt de koppelingsaanvraag. Lukt dat, dan onthoudt het toestel voor
    /// welk bedrijf het was; de beheerder handelt de rest af en de gebruiker komt
    /// binnen via de bedrijfscode of doordat hij wordt toegevoegd.
    @discardableResult
    func requestCompanyLink(userId: String, token: String) async -> Bool {
        let naam = aanvraagNaam.trimmingCharacters(in: .whitespacesAndNewlines)
        guard naam.count >= 2 else {
            errorMessage = "Vul de naam van het bedrijf in (min. 2 tekens)."
            return false
        }
        errorMessage = nil
        busy = true
        defer { busy = false }
        do {
            _ = try await repository.requestCompanyLink(
                companyName: naam,
                note: aanvraagToelichting.trimmingCharacters(in: .whitespacesAndNewlines),
                token: token
            )
            aanvraagStore.bewaar(naam: naam, userId: userId)
            aanvraagVerstuurdVoor = naam
            aanvraagToelichting = ""
            return true
        } catch {
            errorMessage = Self.errorText(error, fallback: "Aanvraag versturen mislukt.")
            return false
        }
    }

    /// Leest de eerder verstuurde aanvraag terug; de view roept dit aan bij het
    /// tonen van de lege staat.
    func primeAanvraag(userId: String) {
        aanvraagVerstuurdVoor = aanvraagStore.lees(userId: userId)
    }

    /// Aanvraag intrekken is puur lokaal: de beheerder ziet hem nog wel staan, maar
    /// de gebruiker kan opnieuw beginnen (bijvoorbeeld bij een typefout in de naam).
    func wisAanvraag(userId: String) {
        aanvraagStore.wis(userId: userId)
        aanvraagVerstuurdVoor = nil
        aanvraagNaam = ""
    }

    @discardableResult
    func joinCompany(token: String) async -> Bool {
        let trimmed = codeDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Vul een bedrijfscode in."
            return false
        }
        errorMessage = nil
        busy = true
        defer { busy = false }
        do {
            _ = try await repository.joinCompany(code: trimmed, token: token)
            justJoined = true
            return true
        } catch {
            errorMessage = Self.errorText(error, fallback: "Toetreden mislukt.")
            return false
        }
    }

    func load(userId: String, token: String) async {
        if membersResponse == nil { loading = true }
        favorites = favoritesStore.load(userId: userId)
        do {
            let response = try await repository.listMembers(token: token)
            membersResponse = response
            memberColors.prime(
                members: response.items.map { Member(id: $0.id, userId: $0.userId, naam: $0.naam, email: $0.email, avatar: $0.avatar) },
                org: response.org.map { CompanyOrgInfo(id: $0.id, name: $0.name, logo: $0.logo, defaultDurationMin: $0.defaultDurationMin) }
            )
            loadFailed = false
        } catch {
            // Vorige response laten staan: na een geslaagde rolwissel roept die
            // load() aan, en faalde díe, dan "verdween" het hele bedrijf tot je
            // pull-to-refresh deed.
            loadFailed = true
        }
        await laadBedrijfsContacten(userId: userId, token: token)
        await laadMijnBedrijven(userId: userId, token: token)
        loading = false
        refreshing = false
    }

    /// company/mine: leidend voor de wisselrij; BekendeBedrijvenStore is alleen
    /// het offline-geheugen (en de terugval als de route faalt).
    private func laadMijnBedrijven(userId: String, token: String) async {
        let store = BekendeBedrijvenStore.shared
        store.prime(userId: userId)
        do {
            let response = try await repository.listMyOrgs(token: token)
            mijnBedrijven = response.orgs
            store.vervang(response.orgs)
        } catch {
            if mijnBedrijven.isEmpty { mijnBedrijven = store.bedrijven }
        }
    }

    /// Maakt een ander bedrijf actief. Bij succes staat default_org op de server
    /// al om; de view moet daarna AuthStore.refreshCurrentUser() + load() doen.
    func wisselBedrijf(naar orgId: String, token: String) async -> Bool {
        guard wisselBezigOrgId == nil else { return false }
        wisselBezigOrgId = orgId
        defer { wisselBezigOrgId = nil }
        do {
            _ = try await repository.switchOrg(orgId: orgId, token: token)
            // Oude ledenlijst hoort niet even als "vorig bedrijf" te blijven staan.
            membersResponse = nil
            bedrijfsContacten = []
            return true
        } catch let error as CompanyError {
            memberActionErrorMessage = error.message
            return false
        } catch {
            memberActionErrorMessage = "Wisselen van bedrijf mislukt."
            return false
        }
    }

    /// Faalt stil, net als de ledenlijst: geen contacten is geen foutmelding waard.
    private func laadBedrijfsContacten(userId: String, token: String) async {
        guard let orgId = membersResponse?.org?.id, !orgId.isEmpty else {
            bedrijfsContacten = []
            return
        }
        // `defaultOrg` mee: zonder dat levert de server alleen de eigen contacten,
        // en dan miste het bedrijf de contacten die een collega had aangemaakt.
        guard let contacten = try? await contactRepository.fetchContacts(userId: userId, defaultOrg: orgId, token: token) else { return }
        bedrijfsContacten = contacten.filter { $0.org == orgId }
    }

    func refresh(userId: String, token: String) async {
        refreshing = true
        await load(userId: userId, token: token)
    }

    // MARK: - Rol, rechten en verwijderen per lid (plak 4)

    func toggleExpanded(_ memberId: String) {
        expandedMemberId = expandedMemberId == memberId ? nil : memberId
    }

    func changeRole(_ member: CompanyMember, to role: CompanyRole, actingUserId: String, token: String) async {
        guard member.canBeManaged(by: actingUserId), busyMemberId == nil else { return }
        // Guard vóór het dichtklappen: tikken op de rol die het lid al heeft deed
        // anders niets behalve de rij sluiten, en dat leest als een fout.
        guard role != member.role else { return }
        expandedMemberId = nil

        let previous = membersResponse
        busyMemberId = member.id
        updateMember(member.id) { $0.withRole(role) }

        do {
            _ = try await repository.setMemberRole(memberId: member.id, role: role, token: token)
            // Valkuil B: rechten/rol lezen we altijd terug via de route, nooit lokaal
            // definitief maken — de server is de bron van waarheid.
            await load(userId: actingUserId, token: token)
        } catch {
            membersResponse = previous
            memberActionErrorMessage = Self.errorText(error, fallback: "Rol wijzigen mislukt.")
        }
        busyMemberId = nil
    }

    func togglePermission(_ member: CompanyMember, key: CompanyPermission, actingUserId: String, token: String) async {
        guard member.canBeManaged(by: actingUserId), busyMemberId == nil else { return }

        let previous = membersResponse
        let nextValue = !member.value(forPermissionKey: key.rawValue)
        busyMemberId = member.id
        updateMember(member.id) { $0.withPermission(key: key.rawValue, value: nextValue) }

        do {
            _ = try await repository.setMemberPermissions(memberId: member.id, key: key.rawValue, value: nextValue, token: token)
            await load(userId: actingUserId, token: token)
        } catch {
            membersResponse = previous
            memberActionErrorMessage = Self.errorText(error, fallback: "Rechten wijzigen mislukt.")
        }
        busyMemberId = nil
    }

    func removeMember(_ member: CompanyMember, actingUserId: String, token: String) async {
        guard member.canBeManaged(by: actingUserId), busyMemberId == nil else { return }
        expandedMemberId = nil

        let previous = membersResponse
        busyMemberId = member.id
        updateMember(removing: member.id)

        do {
            _ = try await repository.removeMember(memberId: member.id, token: token)
            await load(userId: actingUserId, token: token)
        } catch {
            membersResponse = previous
            memberActionErrorMessage = Self.errorText(error, fallback: "Lid verwijderen mislukt.")
        }
        busyMemberId = nil
    }

    private func updateMember(_ id: String, transform: (CompanyMember) -> CompanyMember) {
        guard let response = membersResponse else { return }
        membersResponse = response.replacing(items: response.items.map { $0.id == id ? transform($0) : $0 })
    }

    private func updateMember(removing id: String) {
        guard let response = membersResponse else { return }
        membersResponse = response.replacing(items: response.items.filter { $0.id != id })
    }

    private static func errorText(_ error: Error, fallback: String) -> String {
        (error as? CompanyError)?.message ?? fallback
    }
}
