import SwiftUI

private let minPasswordLength = 8

/// Wachtwoord wijzigen (plak 4). Valkuil C: na succes logt `AuthStore.changePassword`
/// zelf stil opnieuw in — hier alleen het scherm dicht en een bevestiging tonen.
struct WachtwoordView: View {
    @EnvironmentObject private var authStore: AuthStore
    @Environment(\.dismiss) private var dismiss
    @State private var current = ""
    @State private var next = ""
    @State private var repeatPassword = ""
    @State private var showPasswords = false
    @State private var busy = false
    @State private var errorMessage: String?

    private var canSubmit: Bool {
        !current.isEmpty && next.count >= minPasswordLength && !repeatPassword.isEmpty && !busy
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: BovexaTheme.Space.xl) {
                        Text("Kies een nieuw wachtwoord van minimaal \(minPasswordLength) tekens.")
                            .font(BovexaTheme.TypeStyle.subheadline)
                            .foregroundStyle(BovexaTheme.Colors.inkSoft)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        GlassCard {
                            VStack(spacing: BovexaTheme.Space.md) {
                                field(placeholder: "Huidig wachtwoord", text: $current)
                                field(placeholder: "Nieuw wachtwoord", text: $next)
                                field(placeholder: "Herhaal nieuw wachtwoord", text: $repeatPassword)

                                Button {
                                    withAnimation(.snappy) { showPasswords.toggle() }
                                } label: {
                                    Text(showPasswords ? "Verberg wachtwoorden" : "Toon wachtwoorden")
                                        .font(BovexaTheme.TypeStyle.footnote.weight(.medium))
                                        .foregroundStyle(BovexaTheme.Colors.accent)
                                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .trailing)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)

                                if let errorMessage {
                                    Text(errorMessage)
                                        .font(BovexaTheme.TypeStyle.footnote)
                                        .foregroundStyle(BovexaTheme.Colors.danger)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }

                        Button {
                            Task { await submit() }
                        } label: {
                            HStack {
                                Spacer()
                                if busy {
                                    ProgressView().tint(BovexaTheme.Colors.white)
                                } else {
                                    Text("Wachtwoord wijzigen").font(BovexaTheme.TypeStyle.headline)
                                }
                                Spacer()
                            }
                        }
                        .buttonStyle(.glassProminentBrand)
                        .disabled(!canSubmit)
                    }
                    .padding(BovexaTheme.Space.xl)
                    // Sheet, dus geen tabbalk eronder: tabBarClearance (104) liet hier
                    // een gat achter (5c).
                    .padding(.bottom, BovexaTheme.Space.xl)
                }
            }
            .navigationTitle("Wachtwoord")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuleren") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func field(placeholder: String, text: Binding<String>) -> some View {
        Group {
            if showPasswords {
                TextField(placeholder, text: text)
            } else {
                SecureField(placeholder, text: text)
            }
        }
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .font(BovexaTheme.TypeStyle.body)
        .foregroundStyle(BovexaTheme.Colors.ink)
        .padding(BovexaTheme.Space.sm)
        .background(BovexaTheme.Colors.glassSoft)
        .clipShape(RoundedRectangle(cornerRadius: BovexaTheme.Radius.sm, style: .continuous))
    }

    private func submit() async {
        guard canSubmit else { return }
        guard next == repeatPassword else {
            errorMessage = "Wachtwoorden komen niet overeen."
            return
        }
        errorMessage = nil
        busy = true
        defer { busy = false }
        do {
            try await authStore.changePassword(current: current, new: next)
            Haptics.success()
            dismiss()
        } catch let error as PBError {
            if case .server(let status, _) = error, status == 400 {
                errorMessage = "Huidig wachtwoord klopt niet."
            } else {
                errorMessage = "Wijzigen mislukt. Probeer het nog een keer."
            }
            Haptics.warning()
        } catch {
            errorMessage = "Wijzigen mislukt. Probeer het nog een keer."
            Haptics.warning()
        }
    }
}
