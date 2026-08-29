import SwiftUI
import UIKit

/// Bedrijf-tab: zonder bedrijf (starten/toetreden), met bedrijf (bedrijfskaart +
/// ledenlijst). Teambeheer (plak 5) hangt achter het team-icoon rechtsboven.
struct BedrijfView: View {
    @EnvironmentObject private var authStore: AuthStore
    @StateObject private var viewModel = BedrijfViewModel()
    /// Sheet met het bestaande starten/toetreden-scherm, geopend via
    /// "Bedrijf toevoegen" in de wissel-sheet.
    @State private var toontNieuwBedrijf = false
    /// Wissel-sheet: opent door op het logo op de bedrijfskaart te tikken.
    @State private var toontWisselSheet = false

    private var currentUser: AgendaUser? {
        if case .loggedIn(let user) = authStore.phase { return user }
        return nil
    }

    private var hasCompany: Bool {
        viewModel.justJoined || currentUser?.defaultOrg != nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                if let user = currentUser {
                    if hasCompany {
                        companyContent(for: user)
                    } else {
                        EmptyOrgView(viewModel: viewModel) {
                            Task {
                                await authStore.refreshCurrentUser()
                                await viewModel.load(userId: user.id, token: authStore.token ?? "")
                            }
                        }
                    }
                } else {
                    ProgressView().tint(BovexaTheme.Colors.blue)
                }
            }
            .navigationTitle("Bedrijf")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if let user = currentUser, hasCompany, viewModel.isAdmin(user.id) {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink {
                            TeambeheerView(onChanged: refreshAfterChange)
                        } label: {
                            Image(systemName: "person.2.fill")
                        }
                        .accessibilityLabel("Teambeheer")
                    }
                }
            }
        }
        .task { await loadIfNeeded() }
        .onChange(of: hasCompany) { _, nowHasCompany in
            guard nowHasCompany, let user = currentUser else { return }
            Task { await viewModel.load(userId: user.id, token: authStore.token ?? "") }
        }
    }

    private func loadIfNeeded() async {
        guard hasCompany, let user = currentUser else { return }
        await viewModel.load(userId: user.id, token: authStore.token ?? "")
    }

    /// Terug uit Beheer (logo/naam gewijzigd) of uit de achtergrond: zonder dit
    /// bleef de kaart het oude logo en aantal leden tonen tot je trok of herstartte.
    private func refreshAfterChange() {
        Task { await loadIfNeeded() }
    }

    @ViewBuilder
    private func companyContent(for user: AgendaUser) -> some View {
        if viewModel.loading {
            ProgressView().tint(BovexaTheme.Colors.blue)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: BovexaTheme.Space.lg) {
                    if viewModel.loadFailed {
                        LoadFailedNote(surface: .background)
                    }

                    BedrijfCardView(
                        viewModel: viewModel,
                        kanWisselen: !viewModel.mijnBedrijven.isEmpty,
                        onWissel: { toontWisselSheet = true }
                    )

                    if !viewModel.members.isEmpty {
                        // Alleen accounts tellen mee: wie geen inlog heeft is een
                        // contact van iemand persoonlijk, geen teamlid.
                        let totaal = viewModel.members.count
                        VStack(alignment: .leading, spacing: BovexaTheme.Space.sm) {
                            HStack {
                                Text("Team")
                                    .font(BovexaTheme.TypeStyle.headline)
                                    .foregroundStyle(BovexaTheme.Colors.ink)
                                Spacer()
                                Text("\(totaal) \(totaal == 1 ? "lid" : "leden")")
                                    .font(BovexaTheme.TypeStyle.footnote)
                                    .foregroundStyle(BovexaTheme.Colors.inkSoft)
                            }
                            LedenLijstView(
                                viewModel: viewModel,
                                currentUserId: user.id,
                                canManage: viewModel.isAdmin(user.id),
                                token: authStore.token ?? ""
                            )

                        }
                    }
                }
                .padding(BovexaTheme.Space.xl)
                .padding(.bottom, BovexaTheme.Space.tabBarClearance)
            }
            .refreshable {
                await viewModel.refresh(userId: user.id, token: authStore.token ?? "")
            }
            .sheet(isPresented: $toontWisselSheet) {
                wisselSheet(for: user)
            }
            .sheet(isPresented: $toontNieuwBedrijf) {
                nieuwBedrijfSheet(for: user)
            }
        }
    }
}

private extension BedrijfView {
    /// Wissel-sheet, geopend via het logo op de bedrijfskaart: één rij per
    /// bedrijf, het actieve met vinkje, plus "Bedrijf toevoegen". Tikken op een
    /// ander bedrijf wisselt server-side (company/switch) en laadt daarna alles
    /// opnieuw; de overige tabs volgen vanzelf omdat elke tabwissel opnieuw laadt.
    @ViewBuilder
    func wisselSheet(for user: AgendaUser) -> some View {
        VStack(alignment: .leading, spacing: BovexaTheme.Space.lg) {
            Text("Wissel bedrijf")
                .font(BovexaTheme.TypeStyle.title2)
                .foregroundStyle(BovexaTheme.Colors.ink)

            VStack(spacing: BovexaTheme.Space.sm) {
                ForEach(viewModel.mijnBedrijven) { org in
                    let isActief = org.id == user.defaultOrg
                    Button {
                        guard !isActief else {
                            toontWisselSheet = false
                            return
                        }
                        toontWisselSheet = false
                        Task { await wisselNaar(org.id, user: user) }
                    } label: {
                        HStack(spacing: BovexaTheme.Space.md) {
                            orgLogo(org)
                            Text(org.name)
                                .lineLimit(1)
                            Spacer()
                            if viewModel.wisselBezigOrgId == org.id {
                                ProgressView().controlSize(.mini)
                            } else if isActief {
                                Image(systemName: "checkmark")
                                    .font(.callout.weight(.bold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(isActief ? AnyButtonStyle(.glassProminentBrand) : AnyButtonStyle(.glassSecondaryBrand))
                    .disabled(viewModel.wisselBezigOrgId != nil)
                    .accessibilityLabel(isActief ? "\(org.name), actief bedrijf" : "Wissel naar \(org.name)")
                }

                Button {
                    toontWisselSheet = false
                    toontNieuwBedrijf = true
                } label: {
                    Label("Bedrijf toevoegen", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(AnyButtonStyle(.glassSecondaryBrand))
            }

            Spacer(minLength: 0)
        }
        .padding(BovexaTheme.Space.xl)
        .presentationDetents([.medium])
        .presentationBackground(.thinMaterial)
    }

    @ViewBuilder
    func nieuwBedrijfSheet(for user: AgendaUser) -> some View {
            NavigationStack {
                ZStack {
                    AppBackground()
                    EmptyOrgView(viewModel: viewModel) {
                        toontNieuwBedrijf = false
                        Task {
                            await authStore.refreshCurrentUser()
                            await viewModel.load(userId: user.id, token: authStore.token ?? "")
                            // Nieuw bedrijf = ook een wissel van default_org.
                            authStore.markForeground()
                        }
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            toontNieuwBedrijf = false
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .accessibilityLabel("Sluiten")
                    }
                }
            }
    }

    /// Klein bedrijfslogo voor de wisselrijen. Zelfde bronnen als de grote kaart:
    /// server-bestand als het er is, het meegeleverde Betuwe-logo als tijdelijke
    /// uitzondering, en anders het koffertje op dezelfde maat.
    @ViewBuilder
    func orgLogo(_ org: OrgSummary) -> some View {
        let maat: CGFloat = 36
        if let bestand = org.logo, !bestand.isEmpty,
           let url = URL(string: "\(PBEndpoint.base.absoluteString)/api/files/agenda_orgs/\(org.id)/\(bestand)") {
            RemoteLogoView(url: url)
                .frame(width: maat, height: maat)
        } else if org.name.localizedCaseInsensitiveContains("Voetbalschool De Betuwe") {
            Image("BedrijfLogoBetuwe")
                .resizable()
                .scaledToFit()
                .frame(width: maat, height: maat)
        } else {
            RoundedRectangle(cornerRadius: BovexaTheme.Radius.sm, style: .continuous)
                .fill(BovexaTheme.Colors.glassStrong)
                .frame(width: maat, height: maat)
                .overlay(
                    Image(systemName: "briefcase.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(BovexaTheme.Colors.accent)
                )
        }
    }

    func wisselNaar(_ orgId: String, user: AgendaUser) async {
        let gelukt = await viewModel.wisselBedrijf(naar: orgId, token: authStore.token ?? "")
        guard gelukt else { return }
        await authStore.refreshCurrentUser()
        await viewModel.load(userId: user.id, token: authStore.token ?? "")
        // Vandaag, Agenda, Dagtaken en Profiel hangen aan foregroundTick; zonder
        // deze tik bleven zij de data van het vorige bedrijf tonen tot je de app
        // naar de achtergrond stuurde.
        authStore.markForeground()
    }

    /// Eén persoon die bij het bedrijf hoort maar geen account heeft. Geen rol-pil
    /// en geen ster: er valt niets te beheren aan iemand die niet kan inloggen.
    @ViewBuilder
    func contactRij(_ contact: AgendaContact, eerste: Bool) -> some View {
        if !eerste {
            Divider().overlay(BovexaTheme.Colors.edge)
        }
        HStack(spacing: BovexaTheme.Space.md) {
            AvatarView(initial: String(contact.naam.prefix(1)).uppercased(), url: nil, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(contact.naam)
                    .font(BovexaTheme.TypeStyle.subheadline.weight(.semibold))
                    .foregroundStyle(BovexaTheme.Colors.ink)
                Text("Medewerker · geen account")
                    .font(BovexaTheme.TypeStyle.footnote)
                    .foregroundStyle(BovexaTheme.Colors.inkSoft)
            }
            Spacer()
        }
        .padding(.vertical, BovexaTheme.Space.sm)
        .padding(.horizontal, BovexaTheme.Space.sm)
    }
}

/// Bedrijfskaart: naam, logo, aantal leden/stoelen en het ICS-abonnement
/// (valkuil F: webcal-link, geen download).
private struct BedrijfCardView: View {
    @ObservedObject var viewModel: BedrijfViewModel
    /// Aan zodra dit account meer dan nul bedrijven kent: het logo wordt dan de
    /// wisselknop, met een klein pijltjes-embleem als vindbaarheidshint.
    var kanWisselen = false
    var onWissel: () -> Void = {}

    var body: some View {
        GlassCard(emphasis: .hero) {
            VStack(spacing: BovexaTheme.Space.sm) {
                // Het logo staat groot bovenaan en de naam eronder: dit is de kop
                // van de tab, dus het bedrijf mag hier het beeld bepalen in plaats
                // van als klein vierkantje naast de tekst te staan.
                // Geen zichtbaar wissel-embleem (keuze Ibrahim 29 aug): het logo
                // zélf is de knop, de sheet legt uit wat er gebeurt.
                if kanWisselen {
                    Button {
                        Haptics.selection()
                        onWissel()
                    } label: {
                        logo
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Wissel bedrijf")
                } else {
                    logo
                }
                VStack(spacing: 2) {
                    Text(viewModel.org?.name ?? "Jouw bedrijf")
                        .font(BovexaTheme.TypeStyle.title2)
                        .foregroundStyle(BovexaTheme.Colors.ink)
                        .multilineTextAlignment(.center)
                    if let seatsText = viewModel.seatsText {
                        Text(seatsText)
                            .font(BovexaTheme.TypeStyle.footnote)
                            .foregroundStyle(BovexaTheme.Colors.inkSoft)
                    }
                }
                .frame(maxWidth: .infinity)

                if let icsToken = viewModel.org?.icsToken, !icsToken.isEmpty {
                    Button {
                        Haptics.selection()
                        openCalendarFeed(token: icsToken)
                    } label: {
                        Label("In iPhone Agenda", systemImage: "calendar.badge.plus")
                    }
                    .buttonStyle(.glassSecondaryBrand)
                }
            }
        }
    }

    /// Zie de toelichting bij `logo`: alleen dit ene bedrijf heeft een logo in de
    /// app zitten, andere bedrijven krijgen het koffertje tot ze zelf uploaden.
    private var meegeleverdLogo: Bool {
        (viewModel.org?.name ?? "").localizedCaseInsensitiveContains("Voetbalschool De Betuwe")
    }

    @ViewBuilder
    private var logo: some View {
        if let org = viewModel.org, !org.logo.isEmpty,
           let url = URL(string: "\(PBEndpoint.base.absoluteString)/api/files/agenda_orgs/\(org.id)/\(org.logo)") {
            RemoteLogoView(url: url)
                .frame(width: 132, height: 132)
                .padding(.top, BovexaTheme.Space.xs)
        } else if meegeleverdLogo {
            // Tijdelijk: het logo van Voetbalschool De Betuwe zit in de app zelf,
            // omdat het uploaden naar de org een beheerdersaccount vraagt. Zodra
            // het via Beheer > Logo geüpload is wint de bovenstaande tak vanzelf
            // en mag dit blok weg.
            Image("BedrijfLogoBetuwe")
                .resizable()
                .scaledToFit()
                .frame(width: 132, height: 132)
                .padding(.top, BovexaTheme.Space.xs)
        } else {
            // Zonder geüpload logo blijft het koffertje, maar dan op dezelfde
            // grootte — anders springt de kaart van hoogte zodra er een logo bij komt.
            RoundedRectangle(cornerRadius: BovexaTheme.Radius.lg, style: .continuous)
                .fill(BovexaTheme.Colors.glassStrong)
                .frame(width: 132, height: 132)
                .overlay(
                    Image(systemName: "briefcase.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(BovexaTheme.Colors.accent)
                )
                .padding(.top, BovexaTheme.Space.xs)
        }
    }

    /// webcal:// laat iOS zelf het agenda-abonnement aanbieden — dit is geen
    /// download en staat los van de EventKit-sync uit m3.
    private func openCalendarFeed(token: String) {
        guard let host = PBEndpoint.base.host,
              let url = URL(string: "webcal://\(host)/api/agenda/ics/\(token).ics") else { return }
        UIApplication.shared.open(url)
    }
}

/// Zonder bedrijf: koppeling aanvragen bij de beheerder, of toetreden met een
/// bedrijfscode. Zelf een bedrijf starten kan hier sinds 25 augustus niet meer —
/// dat hoort bij de beheerder, niet bij ieder nieuw account.
private struct EmptyOrgView: View {
    @ObservedObject var viewModel: BedrijfViewModel
    @EnvironmentObject private var authStore: AuthStore
    let onSucceeded: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: BovexaTheme.Space.xl) {
                Spacer(minLength: BovexaTheme.Space.xxl)

                VStack(spacing: BovexaTheme.Space.sm) {
                    Image(systemName: "briefcase.fill")
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(BovexaTheme.Colors.accent)
                    Text(title)
                        .font(BovexaTheme.TypeStyle.title2)
                        .foregroundStyle(BovexaTheme.Colors.ink)
                    if viewModel.emptyMode == .choice {
                        Text("Vraag koppeling aan bij de beheerder, of treed meteen toe met een bedrijfscode van een collega.")
                            .font(BovexaTheme.TypeStyle.subheadline)
                            .foregroundStyle(BovexaTheme.Colors.inkSoft)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, BovexaTheme.Space.xl)

                switch viewModel.emptyMode {
                case .choice:
                    choiceButtons
                case .name:
                    form(placeholder: "Bovexa BV", text: $viewModel.nameDraft, autocapitalize: .words)
                case .code:
                    form(placeholder: "BOVEXA-7F3K", text: $viewModel.codeDraft, autocapitalize: .characters)
                case .aanvraag:
                    aanvraagForm
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(BovexaTheme.TypeStyle.footnote)
                        .foregroundStyle(BovexaTheme.Colors.danger)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, BovexaTheme.Space.xl)
                }

                Spacer(minLength: BovexaTheme.Space.xxl)
            }
            .frame(maxWidth: .infinity)
        }
        // Een lopende aanvraag hoort er na een herstart nog te staan; hij leeft op
        // dit toestel omdat de server hem nog niet als lijst kent.
        .task {
            if let userId = currentUserId { viewModel.primeAanvraag(userId: userId) }
        }
    }

    private var title: String {
        switch viewModel.emptyMode {
        case .choice: return "Nog geen bedrijf"
        case .name: return "Bedrijfsnaam"
        case .code: return "Bedrijfscode"
        case .aanvraag: return viewModel.aanvraagVerstuurdVoor == nil ? "Bedrijf koppelen" : "Aanvraag verstuurd"
        }
    }

    private var choiceButtons: some View {
        VStack(spacing: BovexaTheme.Space.sm) {
            // "Start een bedrijf" stond hier tot 25 augustus als eerste knop.
            // Een nieuw account hoort geen bedrijf te kunnen oprichten: dat is aan
            // de beheerder. Wat overblijft is een aanvraag doen, of naar binnen met
            // een code die de beheerder heeft gegeven.
            Button {
                Haptics.selection()
                viewModel.openMode(.aanvraag)
            } label: {
                Label("Bedrijf koppelen", systemImage: "briefcase.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminentBrand)

            Button {
                Haptics.selection()
                viewModel.openMode(.code)
            } label: {
                Label("Voer bedrijfscode in", systemImage: "person.2.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassSecondaryBrand)
        }
        .padding(.horizontal, BovexaTheme.Space.xl)
    }

    /// Koppelingsaanvraag: bedrijfsnaam, een korte toelichting voor de beheerder,
    /// en na het versturen een bevestiging in plaats van hetzelfde formulier —
    /// anders lijkt het alsof er niets is gebeurd en stuurt iedereen hem twee keer.
    @ViewBuilder
    private var aanvraagForm: some View {
        if let bedrijf = viewModel.aanvraagVerstuurdVoor {
            VStack(spacing: BovexaTheme.Space.md) {
                GlassCard {
                    VStack(alignment: .leading, spacing: BovexaTheme.Space.xs) {
                        Label("Aanvraag verstuurd", systemImage: "checkmark.circle.fill")
                            .font(BovexaTheme.TypeStyle.subheadline.weight(.bold))
                            .foregroundStyle(BovexaTheme.Colors.accent)
                        Text("De beheerder van \(bedrijf) moet je koppelen. Zodra dat gebeurd is — of zodra je een bedrijfscode krijgt — kun je hier naar binnen.")
                            .font(BovexaTheme.TypeStyle.footnote)
                            .foregroundStyle(BovexaTheme.Colors.inkSoft)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    Haptics.selection()
                    viewModel.openMode(.code)
                } label: {
                    Label("Ik heb een bedrijfscode", systemImage: "person.2.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminentBrand)

                Button("Aanvraag intrekken") {
                    Haptics.selection()
                    if let userId = currentUserId { viewModel.wisAanvraag(userId: userId) }
                }
                .buttonStyle(.glassSecondaryBrand)
            }
            .padding(.horizontal, BovexaTheme.Space.xl)
        } else {
            VStack(spacing: BovexaTheme.Space.md) {
                GlassCard {
                    VStack(alignment: .leading, spacing: BovexaTheme.Space.sm) {
                        TextField("Naam van het bedrijf", text: $viewModel.aanvraagNaam)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .font(BovexaTheme.TypeStyle.body)
                            .foregroundStyle(BovexaTheme.Colors.ink)

                        Divider().overlay(BovexaTheme.Colors.edgeSoft)

                        TextField("Toelichting voor de beheerder (mag leeg)", text: $viewModel.aanvraagToelichting, axis: .vertical)
                            .lineLimit(2...4)
                            .font(BovexaTheme.TypeStyle.body)
                            .foregroundStyle(BovexaTheme.Colors.ink)
                    }
                }

                Text("De beheerder krijgt je aanvraag en koppelt je aan het bedrijf. Tot die tijd werkt de app gewoon voor je eigen agenda en dagtaken.")
                    .font(BovexaTheme.TypeStyle.footnote)
                    .foregroundStyle(BovexaTheme.Colors.inkSoft)
                    .multilineTextAlignment(.center)

                Button {
                    Haptics.selection()
                    Task { await verstuurAanvraag() }
                } label: {
                    if viewModel.busy {
                        ProgressView().tint(BovexaTheme.Colors.white)
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Aanvraag versturen")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.glassProminentBrand)
                .disabled(!viewModel.canRequest)

                Button("Terug") {
                    Haptics.selection()
                    viewModel.openMode(.choice)
                }
                .buttonStyle(.glassSecondaryBrand)
            }
            .padding(.horizontal, BovexaTheme.Space.xl)
        }
    }

    private var currentUserId: String? {
        if case .loggedIn(let user) = authStore.phase { return user.id }
        return nil
    }

    private func verstuurAanvraag() async {
        guard let userId = currentUserId else { return }
        let gelukt = await viewModel.requestCompanyLink(userId: userId, token: authStore.token ?? "")
        gelukt ? Haptics.success() : Haptics.warning()
    }

    private func form(placeholder: String, text: Binding<String>, autocapitalize: TextInputAutocapitalization) -> some View {
        VStack(spacing: BovexaTheme.Space.md) {
            GlassCard {
                TextField(placeholder, text: text)
                    .textInputAutocapitalization(autocapitalize)
                    .autocorrectionDisabled()
                    .font(BovexaTheme.TypeStyle.body)
                    .foregroundStyle(BovexaTheme.Colors.ink)
            }

            Button {
                Haptics.selection()
                Task { await submit() }
            } label: {
                if viewModel.busy {
                    ProgressView().tint(BovexaTheme.Colors.white)
                        .frame(maxWidth: .infinity)
                } else {
                    Text(viewModel.emptyMode == .code ? "Toetreden" : "Bedrijf aanmaken")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.glassProminentBrand)
            .disabled(viewModel.emptyMode == .code ? !viewModel.canJoin : !viewModel.canCreate)

            Button("Terug") {
                Haptics.selection()
                viewModel.openMode(.choice)
            }
            .buttonStyle(.glassSecondaryBrand)
        }
        .padding(.horizontal, BovexaTheme.Space.xl)
    }

    private func submit() async {
        let token = authStore.token ?? ""
        let success = viewModel.emptyMode == .code
            ? await viewModel.joinCompany(token: token)
            : await viewModel.createCompany(token: token)
        if success {
            Haptics.success()
            onSucceeded()
        } else {
            Haptics.warning()
        }
    }
}

/// Type-eraser zodat de wisselchips per staat (actief/inactief) een andere
/// glasstijl kunnen krijgen zonder de knop twee keer uit te schrijven.
private struct AnyButtonStyle: ButtonStyle {
    private let make: (Configuration) -> AnyView

    init<S: ButtonStyle>(_ style: S) {
        make = { AnyView(style.makeBody(configuration: $0)) }
    }

    func makeBody(configuration: Configuration) -> some View {
        make(configuration)
    }
}

#Preview {
    BedrijfView().environmentObject(AuthStore())
}
