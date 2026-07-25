import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var authStore: AuthStore
    @State private var authMode: AuthMode = .signIn
    @State private var naam = ""
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
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

                            HStack {
                                field(placeholder: "Wachtwoord") {
                                    Group {
                                        if showPassword {
                                            TextField("", text: $password)
                                        } else {
                                            SecureField("", text: $password)
                                        }
                                    }
                                    .textContentType(.password)
                                }

                                Button(showPassword ? "Verberg" : "Toon") {
                                    withAnimation(.snappy) {
                                        showPassword.toggle()
                                    }
                                }
                                .font(BovexaTheme.TypeStyle.footnote.weight(.medium))
                                .foregroundStyle(BovexaTheme.Colors.accent)
                            }

                            if isSignIn {
                                Button("Wachtwoord vergeten?") {
                                    Task { await forgotPassword() }
                                }
                                .font(BovexaTheme.TypeStyle.footnote.weight(.medium))
                                .foregroundStyle(BovexaTheme.Colors.accent)
                                .frame(maxWidth: .infinity, alignment: .trailing)
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
                            .disabled(isSubmitting || !canSubmit)
                            .opacity(isSubmitting || !canSubmit ? 0.6 : 1)
                        }
                    }

                    Button {
                        withAnimation(.snappy) {
                            authMode = isSignIn ? .signUp : .signIn
                        }
                    } label: {
                        Text(isSignIn ? "Nog geen account? " : "Al een account? ")
                            .foregroundStyle(BovexaTheme.Colors.muted)
                        + Text(isSignIn ? "Maak er een" : "Inloggen")
                            .foregroundStyle(BovexaTheme.Colors.accent)
                            .fontWeight(.bold)
                    }
                    .font(BovexaTheme.TypeStyle.footnote)
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

    private var canSubmit: Bool {
        guard !email.isEmpty, !password.isEmpty else { return false }
        return isSignIn || !naam.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

    private func forgotPassword() async {
        let target = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty else {
            resetAlert = .missingEmail
            return
        }
        let success = await authStore.requestPasswordReset(email: target)
        resetAlert = success ? .sent(target) : .failed
    }
}

#Preview {
    LoginView().environmentObject(AuthStore())
}
