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
                            .font(.system(size: BovexaTheme.TypeScale.h1, weight: .bold))
                            .foregroundStyle(BovexaTheme.Colors.ink)
                        Text("Log in om verder te gaan")
                            .font(.system(size: BovexaTheme.TypeScale.body))
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
                                    showPassword.toggle()
                                }
                                .font(.system(size: BovexaTheme.TypeScale.small, weight: .medium))
                                .foregroundStyle(BovexaTheme.Colors.accent)
                            }

                            if let errorMessage {
                                Text(errorMessage)
                                    .font(.system(size: BovexaTheme.TypeScale.small))
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
                                            .font(.system(size: BovexaTheme.TypeScale.title, weight: .semibold))
                                            .foregroundStyle(BovexaTheme.Colors.white)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, BovexaTheme.Space.sm)
                                .background(
                                    LinearGradient(colors: BovexaTheme.Gradients.teal, startPoint: .leading, endPoint: .trailing)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: BovexaTheme.Radius.md, style: .continuous))
                            }
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
                .font(.system(size: BovexaTheme.TypeScale.tiny, weight: .medium))
                .foregroundStyle(BovexaTheme.Colors.muted)
            content()
                .font(.system(size: BovexaTheme.TypeScale.body))
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
    }
}

#Preview {
    LoginView().environmentObject(AuthStore())
}
