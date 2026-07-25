import SwiftUI

/// Keuzestap direct na registratie (valkuil A): bedrijf starten, code invoeren of
/// overslaan. RootRouterView toont dit scherm i.p.v. de tabs zolang
/// `authStore.justRegistered` aan staat.
struct OnboardingView: View {
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var joinCoordinator: JoinCoordinator
    @StateObject private var viewModel = OnboardingViewModel()

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(spacing: BovexaTheme.Space.xl) {
                    VStack(spacing: BovexaTheme.Space.sm) {
                        Image(systemName: viewModel.mode == .code ? "person.2.fill" : "briefcase.fill")
                            .font(.system(size: 26, weight: .medium))
                            .foregroundStyle(BovexaTheme.Colors.accent)
                        Text(title)
                            .font(BovexaTheme.TypeStyle.title2)
                            .foregroundStyle(BovexaTheme.Colors.ink)
                        if viewModel.mode == .choice {
                            Text("Werk je met een team? Koppel je bedrijf, of begin solo.")
                                .font(BovexaTheme.TypeStyle.subheadline)
                                .foregroundStyle(BovexaTheme.Colors.inkSoft)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.top, BovexaTheme.Space.xxl)

                    switch viewModel.mode {
                    case .choice:
                        choiceButtons
                    case .name:
                        form(placeholder: "Bovexa BV", text: $viewModel.companyName, autocapitalize: .words)
                    case .code:
                        form(placeholder: "BOVEXA-7F3K", text: $viewModel.joinCode, autocapitalize: .characters)
                    }

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(BovexaTheme.TypeStyle.footnote)
                            .foregroundStyle(BovexaTheme.Colors.danger)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(BovexaTheme.Space.xl)
            }
        }
        .onAppear {
            guard let code = joinCoordinator.pendingCode else { return }
            viewModel.applyPrefilledCode(code)
            joinCoordinator.pendingCode = nil
        }
    }

    private var title: String {
        switch viewModel.mode {
        case .choice: return "Bijna klaar"
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
                Label("Start als bedrijf", systemImage: "briefcase.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminentBrand)

            Button {
                Haptics.selection()
                viewModel.openMode(.code)
            } label: {
                Label("Ik heb een code", systemImage: "person.2.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassSecondaryBrand)

            Button("Start als lid") {
                Haptics.selection()
                authStore.finishOnboarding()
            }
            .font(BovexaTheme.TypeStyle.subheadline.weight(.semibold))
            .foregroundStyle(BovexaTheme.Colors.accent)
            .padding(.top, BovexaTheme.Space.xs)
        }
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
                    Text(viewModel.mode == .code ? "Toetreden" : "Bedrijf aanmaken")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.glassProminentBrand)
            .disabled(viewModel.busy)

            Button("Terug") {
                Haptics.selection()
                viewModel.openMode(.choice)
            }
            .font(BovexaTheme.TypeStyle.subheadline.weight(.semibold))
            .foregroundStyle(BovexaTheme.Colors.accent)
        }
    }

    private func submit() async {
        let token = authStore.token ?? ""
        let success = viewModel.mode == .code
            ? await viewModel.joinCompanyAction(token: token)
            : await viewModel.startCompany(token: token)
        guard success else {
            Haptics.warning()
            return
        }
        Haptics.success()
        await authStore.refreshCurrentUser()
        authStore.finishOnboarding()
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AuthStore())
        .environmentObject(JoinCoordinator())
}
