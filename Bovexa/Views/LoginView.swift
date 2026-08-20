import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var authStore: AuthStore
    @State private var authMode: AuthMode = .signIn
    @State private var naam = ""
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var isResetting = false
    @State private var isSubmitting = false
    @State private var resetAlert: ResetAlert?

    private enum AuthMode {
        case signIn, signUp
    }

    private enum ResetAlert: Identifiable {
        case sent(String)
        case missingEmail
        case failed

        var id: String {
            switch self {
            case .sent(let email): return "sent-\(email)"
            case .missingEmail: return "missing"
            case .failed: return "failed"
            }
        }
    }

    private var isSignIn: Bool { authMode == .signIn }

    private var errorMessage: String? {
        if case .loggedOut(let message) = authStore.phase { return message }
        return nil
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(spacing: BovexaTheme.Space.xl) {
                    VStack(spacing: BovexaTheme.Space.xs) {
                        Text("Bovexa Flow")
                            .font(BovexaTheme.TypeStyle.largeTitle)
                            .foregroundStyle(BovexaTheme.Colors.ink)
                        Text(isSignIn ? "Log in om verder te gaan" : "Maak een account aan")
                            .font(BovexaTheme.TypeStyle.subheadline)
                            .foregroundStyle(BovexaTheme.Colors.muted)
                    }
                    .padding(.top, BovexaTheme.Space.xxl)

                    GlassCard {
                        VStack(spacing: BovexaTheme.Space.md) {
                            if !isSignIn {
                                field(placeholder: "Naam") {
                                    TextField("", text: $naam)
                                        .textContentType(.name)
                                        .textInputAutocapitalization(.words)
                                }
                            }

                            field(placeholder: "E-mailadres") {
                                TextField("", text: $email)
                                    .textContentType(.emailAddress)
                                    .keyboardType(.emailAddress)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                            }

                            // .bottom: de HStack centreerde de knop t.o.v. label +
                            // veld samen, dus hij hing ±11pt boven het veld (5c).
                            HStack(alignment: .bottom) {
                                field(placeholder: "Wachtwoord") {
                                    Group {
                                        if showPassword {
                                            TextField("", text: $password)
                                        } else {
                                            SecureField("", text: $password)
                                        }
                                    }
                                    // .newPassword in registratiemodus: dan biedt
                                    // iOS een sterk wachtwoord aan.
                                    .textContentType(isSignIn ? .password : .newPassword)
                                    .submitLabel(.go)
                                    .onSubmit {
                                        guard canSubmit, !isSubmitting else { return }
                                        Task { await submit() }
                                    }
                                }

                                Button {
                                    withAnimation(.snappy) {
                                        showPassword.toggle()
                                    }
                                } label: {
                                    Text(showPassword ? "Verberg" : "Toon")
                                        .font(BovexaTheme.TypeStyle.footnote.weight(.medium))
                                        .foregroundStyle(BovexaTheme.Colors.accent)
                                        .padding(.horizontal, BovexaTheme.Space.xs)
                                        .frame(minHeight: 44)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }

                            if !isSignIn {
                                Text("Minimaal 8 tekens")
                                    .font(BovexaTheme.TypeStyle.caption)
                                    .foregroundStyle(BovexaTheme.Colors.muted)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            if isSignIn {
                                Button {
                                    Task { await forgotPassword() }
                                } label: {
                                    Text("Wachtwoord vergeten?")
                                        .font(BovexaTheme.TypeStyle.footnote.weight(.medium))
                                        .foregroundStyle(BovexaTheme.Colors.accent)
                                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .trailing)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .disabled(isResetting)
                            }

                            if let errorMessage {
                                Text(errorMessage)
                                    .font(BovexaTheme.TypeStyle.footnote)
                                    .foregroundStyle(BovexaTheme.Colors.danger)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            Button {
                                Task { await submit() }
                            } label: {
                                HStack {
                                    Spacer()
                                    if isSubmitting {
                                        ProgressView().tint(BovexaTheme.Colors.white)
                                    } else {
                                        Text(isSignIn ? "Inloggen" : "Account maken")
                                            .font(BovexaTheme.TypeStyle.headline)
                                    }
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, BovexaTheme.Space.xs)
                            }
                            .buttonStyle(.glassProminentBrand)
                            // Geen extra .opacity: GlassProminentButtonStyle dimt
                            // zelf al (capsule 0.45), en samen werd dat ±0.27 —
                            // precies de grijs-op-grijs die de stijl moest oplossen.
                            .disabled(isSubmitting || !canSubmit)
                        }
                    }

                    Button {
                        withAnimation(.snappy) {
                            authMode = isSignIn ? .signUp : .signIn
                        }
                    } label: {
                        (Text(isSignIn ? "Nog geen account? " : "Al een account? ")
                            .foregroundStyle(BovexaTheme.Colors.muted)
                        + Text(isSignIn ? "Maak er een" : "Inloggen")
                            .foregroundStyle(BovexaTheme.Colors.accent)
                            .fontWeight(.bold))
                            .font(BovexaTheme.TypeStyle.footnote)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(BovexaTheme.Space.xl)
            }
        }
        .alert(item: $resetAlert) { alert in
            switch alert {
            case .sent(let email):
                Alert(title: Text("Check je mail"), message: Text("We hebben een herstellink gestuurd naar \(email) (kan even duren)."))
            case .missingEmail:
                Alert(title: Text("Wachtwoord vergeten?"), message: Text("Vul eerst je e-mail in, dan sturen we je een herstellink."))
            case .failed:
                Alert(title: Text("Mislukt"), message: Text("Kon geen herstellink sturen. Controleer je e-mail of probeer later opnieuw."))
            }
        }
    }

    /// PocketBase eist minimaal 8 tekens bij registreren. Zonder client-check kwam
    /// dat terug als "Registreren mislukt — bestaat het account al?", en dat is
    /// misleidend. Trimmen op e-mail: een enkele spatie telde als ingevuld.
    private var canSubmit: Bool {
        guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !password.isEmpty else { return false }
        guard isSignIn else {
            return password.count >= 8 && !naam.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return true
    }

    @ViewBuilder
    private func field(placeholder: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: BovexaTheme.Space.xs) {
            Text(placeholder)
                .font(BovexaTheme.TypeStyle.footnote.weight(.medium))
                .foregroundStyle(BovexaTheme.Colors.muted)
            content()
                .font(BovexaTheme.TypeStyle.body)
                .foregroundStyle(BovexaTheme.Colors.ink)
                .padding(BovexaTheme.Space.sm)
                .background(BovexaTheme.Colors.glassSoft)
                .clipShape(RoundedRectangle(cornerRadius: BovexaTheme.Radius.sm, style: .continuous))
        }
    }

    private func submit() async {
        isSubmitting = true
        if isSignIn {
            await authStore.signIn(email: email, password: password)
        } else {
            await authStore.signUp(email: email, password: password, naam: naam)
        }
        isSubmitting = false

        // Haptic op het bestaande fase-overgangsmoment — geen nieuwe state, alleen feedback.
        switch authStore.phase {
        case .loggedIn:
            Haptics.success()
        case .loggedOut(let message) where message != nil:
            Haptics.warning()
        default:
            break
        }
    }

    /// Busy-guard: zonder dit stuurden meerdere tikken tijdens de netwerkronde
    /// evenzoveel herstelmails.
    private func forgotPassword() async {
        guard !isResetting else { return }
        let target = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty else {
            resetAlert = .missingEmail
            return
        }
        isResetting = true
        defer { isResetting = false }
        let success = await authStore.requestPasswordReset(email: target)
        resetAlert = success ? .sent(target) : .failed
    }
}

#Preview {
    LoginView().environmentObject(AuthStore())
}
