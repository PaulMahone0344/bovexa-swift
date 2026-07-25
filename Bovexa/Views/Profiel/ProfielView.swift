import SwiftUI

/// Profiel-tab: begroeting, gebruikerskaart en navigatierijen. Vervangt
/// `ProfielPlaceholderView`. Meldingen, Mijn klanten en Profiel bewerken wijzen
/// deze plak nog naar een placeholder (`ComingSoonView`) — sessie B/plak 3-4
/// vullen ze. Wachtwoord wijzigen en Account verwijderen zijn al echt.
struct ProfielView: View {
    @EnvironmentObject private var authStore: AuthStore
    @StateObject private var viewModel = ProfielViewModel()
    @State private var showAfwezig = false
    @State private var showMeldingen = false
    @State private var showKlanten = false
    @State private var showProfielBewerken = false
    @State private var showWachtwoord = false
    @State private var showDeleteConfirm = false
    @State private var deleteFailed = false

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
                        VStack(alignment: .leading, spacing: BovexaTheme.Space.xs) {
                            Text("\(greeting), \(firstName)")
                                .font(BovexaTheme.TypeStyle.title2)
                                .foregroundStyle(BovexaTheme.Colors.ink)
                            Text(viewModel.greetingSubtitle)
                                .font(BovexaTheme.TypeStyle.subheadline)
                                .foregroundStyle(BovexaTheme.Colors.inkSoft)
                        }

                        Button {
                            Haptics.selection()
                            showProfielBewerken = true
                        } label: {
                            GlassCard {
                                HStack(spacing: BovexaTheme.Space.md) {
                                    AvatarView(initial: initial, url: currentUser.flatMap { AvatarURLBuilder.url(userId: $0.id, avatar: $0.avatar) })
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(displayName)
                                            .font(BovexaTheme.TypeStyle.headline)
                                            .foregroundStyle(BovexaTheme.Colors.ink)
                                        Text(currentUser?.email ?? "")
                                            .font(BovexaTheme.TypeStyle.footnote)
                                            .foregroundStyle(BovexaTheme.Colors.inkSoft)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(BovexaTheme.Colors.accent)
                                }
                            }
                        }
                        .buttonStyle(.plain)

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
                            row(icon: "person.2.fill", label: "Mijn klanten") {
                                showKlanten = true
                            }
                            deviceSyncRow
                            row(icon: "lock.fill", label: "Wachtwoord wijzigen") {
                                showWachtwoord = true
                            }
                        }

                        Button("Uitloggen") {
                            Haptics.selection()
                            authStore.signOut()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, BovexaTheme.Space.sm)
                        .foregroundStyle(BovexaTheme.Colors.danger)
                        .font(BovexaTheme.TypeStyle.headline)
                        .buttonStyle(.glassSecondaryBrand)

                        Button("Account verwijderen") {
                            showDeleteConfirm = true
                        }
                        .frame(maxWidth: .infinity)
                        .font(BovexaTheme.TypeStyle.footnote.weight(.semibold))
                        .foregroundStyle(BovexaTheme.Colors.muted)
                        .underline()
                    }
                    .padding(BovexaTheme.Space.xl)
                    .padding(.bottom, BovexaTheme.Space.tabBarClearance)
                }
            }
            .navigationTitle("Profiel")
            .navigationBarTitleDisplayMode(.large)
        }
        .task { await refresh() }
        .onAppear { Task { await refresh() } }
        .sheet(isPresented: $showAfwezig) {
            if let user = currentUser {
                AfwezigView(userId: user.id, org: user.defaultOrg, token: authStore.token ?? "")
            }
        }
        .sheet(isPresented: $showMeldingen) {
            ComingSoonView(title: "Meldingen")
        }
        .sheet(isPresented: $showKlanten) {
            ComingSoonView(title: "Mijn klanten")
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
                Toggle("", isOn: Binding(
                    get: { viewModel.deviceSyncEnabled },
                    set: { viewModel.setDeviceSync($0) }
                ))
                .labelsHidden()
                .tint(BovexaTheme.Colors.teal)
            }
        }
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
                        Circle().fill(BovexaTheme.Colors.tealDark).frame(width: 8, height: 8)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(BovexaTheme.Colors.muted)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func refresh() async {
        guard let user = currentUser else { return }
        await viewModel.load(userId: user.id, orgId: user.defaultOrg, token: authStore.token ?? "")
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
