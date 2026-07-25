import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var authStore: AuthStore
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var isSubmitting = false

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
                        Text("Log in om verder te gaan")
                            .font(BovexaTheme.TypeStyle.subheadline)
                            .foregroundStyle(BovexaTheme.Colors.muted)
                    }
                    .padding(.top, BovexaTheme.Space.xxl)

                    GlassCard {
                        VStack(spacing: BovexaTheme.Space.md) {
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
                                        Text("Inloggen")
                                            .font(BovexaTheme.TypeStyle.headline)
                                    }
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, BovexaTheme.Space.xs)
                            }
                            .buttonStyle(.glassProminentBrand)
                            .disabled(isSubmitting || email.isEmpty || password.isEmpty)
                            .opacity(isSubmitting || email.isEmpty || password.isEmpty ? 0.6 : 1)
                        }
                    }
                }
                .padding(BovexaTheme.Space.xl)
            }
        }
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
        await authStore.signIn(email: email, password: password)
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
}

#Preview {
    LoginView().environmentObject(AuthStore())
}
