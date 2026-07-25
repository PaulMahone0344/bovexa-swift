import SwiftUI

/// Bedrijf-tab: zonder bedrijf (starten/toetreden), met bedrijf (bedrijfskaart +
/// ledenlijst, plak 3).
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
                                await viewModel.load(token: authStore.token ?? "")
                            }
                        }
                    }
                } else {
                    ProgressView().tint(BovexaTheme.Colors.teal)
                }
            }
            .navigationTitle("Bedrijf")
            .navigationBarTitleDisplayMode(.large)
        }
        .task { await loadIfNeeded() }
        .onChange(of: hasCompany) { _, nowHasCompany in
            guard nowHasCompany else { return }
            Task { await viewModel.load(token: authStore.token ?? "") }
        }
    }

    private func loadIfNeeded() async {
        guard hasCompany, let user = currentUser else { return }
        await viewModel.load(token: authStore.token ?? "")
        _ = user
    }

    @ViewBuilder
    private func companyContent(for user: AgendaUser) -> some View {
        if viewModel.loading {
            ProgressView().tint(BovexaTheme.Colors.teal)
        } else {
            Text("Bedrijf")
                .foregroundStyle(BovexaTheme.Colors.ink)
        }
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
