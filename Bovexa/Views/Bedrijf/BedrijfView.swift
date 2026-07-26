import SwiftUI
import UIKit

/// Bedrijf-tab: zonder bedrijf (starten/toetreden), met bedrijf (bedrijfskaart +
/// ledenlijst). Teambeheer (plak 5) hangt achter het team-icoon rechtsboven.
struct BedrijfView: View {
    @EnvironmentObject private var authStore: AuthStore
    @StateObject private var viewModel = BedrijfViewModel()

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
                            TeambeheerView()
                        } label: {
                            Image(systemName: "person.2.fill")
                        }
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

    @ViewBuilder
    private func companyContent(for user: AgendaUser) -> some View {
        if viewModel.loading {
            ProgressView().tint(BovexaTheme.Colors.blue)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: BovexaTheme.Space.lg) {
                    BedrijfCardView(viewModel: viewModel)

                    if !viewModel.members.isEmpty {
                        VStack(alignment: .leading, spacing: BovexaTheme.Space.sm) {
                            HStack {
                                Text("Team")
                                    .font(BovexaTheme.TypeStyle.headline)
                                    .foregroundStyle(BovexaTheme.Colors.ink)
                                Spacer()
                                Text("\(viewModel.members.count) \(viewModel.members.count == 1 ? "lid" : "leden")")
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
        }
    }
}

/// Bedrijfskaart: naam, logo, aantal leden/stoelen en het ICS-abonnement
/// (valkuil F: webcal-link, geen download).
private struct BedrijfCardView: View {
    @ObservedObject var viewModel: BedrijfViewModel

    var body: some View {
        GlassCard(emphasis: .hero) {
            VStack(alignment: .leading, spacing: BovexaTheme.Space.sm) {
                HStack(spacing: BovexaTheme.Space.md) {
                    logo
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.org?.name ?? "Jouw bedrijf")
                            .font(BovexaTheme.TypeStyle.title2)
                            .foregroundStyle(BovexaTheme.Colors.ink)
                        if let seatsText = viewModel.seatsText {
                            Text(seatsText)
                                .font(BovexaTheme.TypeStyle.footnote)
                                .foregroundStyle(BovexaTheme.Colors.inkSoft)
                        }
                    }
                    Spacer()
                }

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

    @ViewBuilder
    private var logo: some View {
        if let org = viewModel.org, !org.logo.isEmpty,
           let url = URL(string: "\(PBEndpoint.base.absoluteString)/api/files/agenda_orgs/\(org.id)/\(org.logo)") {
            AsyncImage(url: url) { image in
                image.resizable().aspectRatio(contentMode: .fit)
            } placeholder: {
                Color.clear
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: BovexaTheme.Radius.sm, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: BovexaTheme.Radius.sm, style: .continuous)
                .fill(BovexaTheme.Colors.glassStrong)
                .frame(width: 44, height: 44)
                .overlay(Image(systemName: "briefcase.fill").foregroundStyle(BovexaTheme.Colors.accent))
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

/// Zonder bedrijf: keuze tussen starten of toetreden, dan een naam- of code-veld.
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
                        Text("Start je eigen bedrijf, of treed toe met een bedrijfscode van een collega.")
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
    }

    private var title: String {
        switch viewModel.emptyMode {
        case .choice: return "Nog geen bedrijf"
        case .name: return "Bedrijfsnaam"
        case .code: return "Bedrijfscode"
        }
    }

    private var choiceButtons: some View {
        VStack(spacing: BovexaTheme.Space.sm) {
            Button {
                Haptics.selection()
                viewModel.openMode(.name)
            } label: {
                Label("Start een bedrijf", systemImage: "briefcase.fill")
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
            .font(BovexaTheme.TypeStyle.subheadline.weight(.semibold))
            .foregroundStyle(BovexaTheme.Colors.accent)
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

#Preview {
    BedrijfView().environmentObject(AuthStore())
}
