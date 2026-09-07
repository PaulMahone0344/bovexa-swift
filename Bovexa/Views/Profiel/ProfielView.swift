import SwiftUI
import UIKit

/// Profiel-tab: begroeting, gebruikerskaart en navigatierijen. Vervangt
/// `ProfielPlaceholderView`. Alle rijen zijn echt: Meldingen, Mensen,
/// Profiel bewerken, wachtwoord wijzigen en account verwijderen.
struct ProfielView: View {
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var badgeStore: BadgeStore
    @StateObject private var viewModel = ProfielViewModel()
    @State private var showAfwezig = false
    @State private var showMeldingen = false
    @State private var showMensen = false
    @State private var showProfielBewerken = false
    @State private var showWachtwoord = false
    @State private var showDeleteConfirm = false
    @State private var deleteFailed = false
    @State private var externalCalendarLink = ""
    @State private var externalCalendarLinkInvalid = false

    private var currentUser: AgendaUser? {
        if case .loggedIn(let user) = authStore.phase { return user }
        return nil
    }

    private var firstName: String {
        let naam = (currentUser?.naam ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if let first = naam.split(separator: " ").first { return String(first) }
        return currentUser?.email.split(separator: "@").first.map(String.init) ?? "daar"
    }

    private var displayName: String {
        let trimmed = currentUser?.naam?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "Naamloos" : trimmed
    }

    private var initial: String {
        let trimmedNaam = currentUser?.naam?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let source = trimmedNaam.isEmpty ? (currentUser?.email ?? "") : trimmedNaam
        guard let first = source.first else { return "?" }
        return String(first).uppercased()
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case ..<12: return "Goedemorgen"
        case ..<18: return "Goedemiddag"
        default: return "Goedenavond"
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: BovexaTheme.Space.lg) {
                        // Grote foto bovenaan, midden op het scherm: dit is jouw
                        // pagina, dus staat je gezicht er ook groot op. De kleine
                        // rij met een pijltje erachter stond hier tot 26 augustus.
                        Button {
                            Haptics.selection()
                            showProfielBewerken = true
                        } label: {
                            VStack(spacing: BovexaTheme.Space.sm) {
                                AvatarView(
                                    initial: initial,
                                    url: currentUser.flatMap { AvatarURLBuilder.url(userId: $0.id, avatar: $0.avatar) },
                                    size: 108
                                )

                                VStack(spacing: 2) {
                                    Text(displayName)
                                        .font(BovexaTheme.TypeStyle.title2)
                                        .foregroundStyle(BovexaTheme.Colors.ink)
                                    Text(currentUser?.email ?? "")
                                        .font(BovexaTheme.TypeStyle.footnote)
                                        .foregroundStyle(BovexaTheme.Colors.inkSoft)
                                        .lineLimit(1)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Profiel bewerken")

                        VStack(alignment: .leading, spacing: BovexaTheme.Space.xs) {
                            Text("\(greeting), \(firstName)")
                                .font(BovexaTheme.TypeStyle.headline)
                                .foregroundStyle(BovexaTheme.Colors.ink)
                            Text(viewModel.greetingSubtitle)
                                .font(BovexaTheme.TypeStyle.subheadline)
                                .foregroundStyle(BovexaTheme.Colors.inkSoft)
                        }

                        VStack(spacing: BovexaTheme.Space.sm) {
                            row(
                                icon: "bell.fill",
                                label: viewModel.pendingCount > 0 ? "Meldingen (\(viewModel.pendingCount))" : "Meldingen",
                                dot: viewModel.showUnreadDot
                            ) {
                                showMeldingen = true
                            }
                            row(icon: "sun.max.fill", label: "Beschikbaarheid doorgeven") {
                                showAfwezig = true
                            }
                            // "Mijn klanten" stond hier tot 26 augustus. Mensen dekt
                            // dezelfde contacten al, dus de aparte klantenrij was
                            // dubbelop. KlantenView blijft bestaan voor later.
                            row(icon: "person.crop.circle.fill.badge.plus", label: "Mensen") {
                                showMensen = true
                            }
                            deviceSyncRow
                            row(icon: "lock.fill", label: "Wachtwoord wijzigen") {
                                showWachtwoord = true
                            }
                        }

                        // Frame ín het label en de danger-variant van de stijl: de
                        // kleur, het lettertype en de breedte stonden op de Button
                        // en werden alle drie door de stijl overschreven, dus deze
                        // knop rendeerde als een smalle blauwe pil.
                        Button {
                            Haptics.selection()
                            authStore.signOut()
                        } label: {
                            Text("Uitloggen").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glassSecondaryDanger)

                        Button {
                            showDeleteConfirm = true
                        } label: {
                            Text("Account verwijderen")
                                .font(BovexaTheme.TypeStyle.footnote.weight(.semibold))
                                .foregroundStyle(BovexaTheme.Colors.muted)
                                .underline()
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(BovexaTheme.Space.xl)
                    .padding(.bottom, BovexaTheme.Space.tabBarClearance)
                }
            }
            .navigationTitle("Profiel")
            .navigationBarTitleDisplayMode(.large)
            // Bij scrollen klapt de titel in; zonder zichtbare balk stond hij
            // dwars over de eerste rij.
            .toolbarBackground(.visible, for: .navigationBar)
        }
        // Eén laadpad: `.task` draait al bij elke (her)verschijning.
        .task { await refresh() }
        .onChange(of: authStore.foregroundTick) { _, _ in
            Task { await refresh() }
        }
        .onChange(of: viewModel.pendingCount, initial: true) { _, count in
            badgeStore.setPendingAssignments(count)
        }
        .onChange(of: viewModel.unreadNoticeCount, initial: true) { _, count in
            badgeStore.setUnreadNotices(count)
        }
        // Beide sheets veranderen wat dit scherm toont — de meldingenteller met
        // stip, en de begroeting met het aantal afspraken van vandaag. Een sheet
        // sluiten vuurt geen .task/.onAppear, dus zonder onDismiss bleven die
        // staan tot een tabwissel.
        .sheet(isPresented: $showAfwezig, onDismiss: { Task { await refresh() } }) {
            if let user = currentUser {
                AfwezigView(userId: user.id, org: user.defaultOrg, token: authStore.token ?? "")
            }
        }
        .sheet(isPresented: $showMeldingen, onDismiss: { Task { await refresh() } }) {
            if let user = currentUser {
                MeldingenView(userId: user.id, orgId: user.defaultOrg, token: authStore.token ?? "")
            }
        }
        .sheet(isPresented: $showMensen) {
            if let user = currentUser {
                MensenView(userId: user.id, defaultOrg: user.defaultOrg ?? "", token: authStore.token ?? "")
            }
        }
        .sheet(isPresented: $showProfielBewerken) {
            if let user = currentUser {
                ProfielBewerkenView(user: user)
            }
        }
        .sheet(isPresented: $showWachtwoord) {
            WachtwoordView()
        }
        .alert("Account verwijderen", isPresented: $showDeleteConfirm) {
            Button("Annuleren", role: .cancel) {}
            Button("Verwijder definitief", role: .destructive) {
                Task { await deleteAccount() }
            }
        } message: {
            Text("Je account en al je gegevens worden definitief verwijderd. Dit kan niet ongedaan worden gemaakt.")
        }
        .alert("Mislukt", isPresented: $deleteFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Kon je account niet verwijderen. Probeer het later opnieuw.")
        }
    }

    private var deviceSyncRow: some View {
        GlassCard(padding: BovexaTheme.Space.md, emphasis: .quiet) {
            VStack(alignment: .leading, spacing: BovexaTheme.Space.md) {
                HStack(spacing: BovexaTheme.Space.md) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(BovexaTheme.Colors.accent)
                        .frame(width: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("iPhone Agenda-sync")
                            .font(BovexaTheme.TypeStyle.subheadline.weight(.semibold))
                            .foregroundStyle(BovexaTheme.Colors.ink)
                        Text("Nieuwe afspraken ook in je iPhone Agenda zetten")
                            .font(BovexaTheme.TypeStyle.caption)
                            .foregroundStyle(BovexaTheme.Colors.muted)
                    }
                    Spacer()
                    // Naam ín de Toggle, .labelsHidden() verbergt hem alleen
                    // visueel: VoiceOver zei anders "schakelaar, aan" zonder waarvan (4j).
                    Toggle("iPhone Agenda-sync", isOn: Binding(
                        get: { viewModel.deviceSyncEnabled },
                        set: { viewModel.setDeviceSync($0) }
                    ))
                    .labelsHidden()
                    .tint(BovexaTheme.Colors.blue)
                }

                Divider().overlay(BovexaTheme.Colors.edgeSoft)

                externalCalendarLinkRow
            }
        }
    }

    /// Losse agenda-link plakken en doorgeven aan iOS via webcal (m8, klantverzoek
    /// 26 juli, variant A) — de app leest de feed zelf niet uit.
    private var externalCalendarLinkRow: some View {
        VStack(alignment: .leading, spacing: BovexaTheme.Space.xs) {
            Text("Andere agenda toevoegen")
                .font(BovexaTheme.TypeStyle.subheadline.weight(.semibold))
                .foregroundStyle(BovexaTheme.Colors.ink)
            Text("Plak een ICS- of webcal-link. Je abonneert je via je iPhone Agenda; de afspraken verschijnen daarna ook hier in Bovexa Flow.")
                .font(BovexaTheme.TypeStyle.caption)
                .foregroundStyle(BovexaTheme.Colors.muted)

            HStack(spacing: BovexaTheme.Space.xs) {
                TextField("https://...", text: $externalCalendarLink)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding(.horizontal, BovexaTheme.Space.md)
                    .frame(minHeight: 40)
                    .background(BovexaTheme.Colors.glass)
                    .overlay(
                        RoundedRectangle(cornerRadius: BovexaTheme.Radius.md, style: .continuous)
                            .strokeBorder(BovexaTheme.Colors.edge, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: BovexaTheme.Radius.md, style: .continuous))

                Button {
                    openExternalCalendarLink()
                } label: {
                    Image(systemName: "link")
                }
                .buttonStyle(.glassSecondaryBrand)
                // Stond aan bij een leeg veld; een tik deed dan stil niets (4d).
                .disabled(externalCalendarLink.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("Agenda-link openen in iPhone Agenda")
            }

            externalCalendarsPickerRow
        }
        .alert("Ongeldige link", isPresented: $externalCalendarLinkInvalid) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Dit is geen geldige agenda-link. Controleer de link en probeer het opnieuw.")
        }
    }

    /// Welke toestelagenda's in Bovexa Flow te zien zijn (m9 plak 3, valkuil F/I).
    /// De toegangsvraag hangt aan de knop hieronder en niet aan het openen van het
    /// scherm: één keer "Sta niet toe" is definitief, dus die vraag moet komen op het
    /// moment dat de gebruiker er zelf om vraagt.
    @ViewBuilder
    private var externalCalendarsPickerRow: some View {
        if viewModel.externalCalendarAccessDenied {
            VStack(alignment: .leading, spacing: BovexaTheme.Space.xs) {
                Text("Geef Bovexa Flow toegang tot je agenda's in Instellingen om afspraken uit een andere agenda hier te zien.")
                    .font(BovexaTheme.TypeStyle.caption)
                    .foregroundStyle(BovexaTheme.Colors.muted)
                // De tekst verwees naar Instellingen zonder een weg ernaartoe (4j).
                Button("Open Instellingen") {
                    Haptics.selection()
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }
                .buttonStyle(.glassSecondaryBrand)
            }
            .padding(.top, BovexaTheme.Space.xs)
        } else if !viewModel.externalCalendarAccessGranted {
            Button {
                Haptics.selection()
                Task { await viewModel.requestExternalCalendarAccess() }
            } label: {
                Label("Agenda's van dit toestel tonen", systemImage: "calendar.badge.plus")
                    .font(BovexaTheme.TypeStyle.footnote.weight(.semibold))
            }
            .buttonStyle(.glassSecondaryBrand)
            .padding(.top, BovexaTheme.Space.xs)
        } else if viewModel.externalCalendars.isEmpty {
            Text("Geen agenda's op dit toestel gevonden.")
                .font(BovexaTheme.TypeStyle.caption)
                .foregroundStyle(BovexaTheme.Colors.muted)
                .padding(.top, BovexaTheme.Space.xs)
        } else {
            VStack(alignment: .leading, spacing: BovexaTheme.Space.xs) {
                Text("Tonen in Bovexa Flow")
                    .font(BovexaTheme.TypeStyle.caption.weight(.semibold))
                    .foregroundStyle(BovexaTheme.Colors.inkSoft)
                    .padding(.top, BovexaTheme.Space.xs)
                ForEach(viewModel.externalCalendars) { calendar in
                    HStack {
                        Text(calendar.title)
                            .font(BovexaTheme.TypeStyle.footnote)
                            .foregroundStyle(BovexaTheme.Colors.ink)
                        Spacer()
                        Toggle(calendar.title, isOn: Binding(
                            get: { viewModel.selectedExternalCalendarIds.contains(calendar.id) },
                            set: { _ in viewModel.toggleExternalCalendar(calendar.id) }
                        ))
                        .labelsHidden()
                        .tint(BovexaTheme.Colors.blue)
                    }
                }
            }
        }
    }

    private func openExternalCalendarLink() {
        Haptics.selection()
        guard let url = WebcalLinkConverter.convert(externalCalendarLink) else {
            if !externalCalendarLink.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                externalCalendarLinkInvalid = true
            }
            return
        }
        UIApplication.shared.open(url)
    }

    @ViewBuilder
    private func row(icon: String, label: String, dot: Bool = false, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            GlassCard(padding: BovexaTheme.Space.md, emphasis: .quiet) {
                HStack(spacing: BovexaTheme.Space.md) {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(BovexaTheme.Colors.accent)
                        .frame(width: 32)
                    Text(label)
                        .font(BovexaTheme.TypeStyle.subheadline.weight(.semibold))
                        .foregroundStyle(BovexaTheme.Colors.ink)
                    Spacer()
                    if dot {
                        Circle().fill(BovexaTheme.Colors.blueDeep).frame(width: 8, height: 8)
                            // De stip is puur visueel; VoiceOver hoorde alleen
                            // "Meldingen", zonder dat er iets ongelezen was (4j).
                            .accessibilityHidden(true)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(BovexaTheme.Colors.muted)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(dot ? "\(label), ongelezen" : label)
    }

    private func refresh() async {
        guard let user = currentUser else { return }
        await viewModel.load(userId: user.id, orgId: user.defaultOrg, token: authStore.token ?? "")
        viewModel.loadExternalCalendarsIfAuthorized()
    }

    private func deleteAccount() async {
        do {
            try await authStore.deleteAccount()
        } catch {
            deleteFailed = true
        }
    }
}

#Preview {
    ProfielView().environmentObject(AuthStore())
}
