import SwiftUI
import PhotosUI

/// Beheer-scherm voor admins: uitnodigen (code/deel/mail/nieuwe code), logo, en
/// bedrijfsprofiel — één plek, bereikbaar via het team-icoon op de Bedrijf-tab.
struct TeambeheerView: View {
    @EnvironmentObject private var authStore: AuthStore
    @StateObject private var viewModel = TeambeheerViewModel()
    @State private var showRotateConfirm = false
    @State private var logoPickerItem: PhotosPickerItem?

    private var token: String { authStore.token ?? "" }

    var body: some View {
        ZStack {
            AppBackground()

            if viewModel.loading {
                ProgressView().tint(BovexaTheme.Colors.blue)
            } else if viewModel.org == nil {
                errorState
            } else {
                content
            }
        }
        .navigationTitle("Beheer")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load(token: token) }
        .alert("Nieuwe bedrijfscode?", isPresented: $showRotateConfirm) {
            Button("Annuleren", role: .cancel) {}
            Button("Doorgaan") { Task { await viewModel.rotateCode(token: token) } }
        } message: {
            Text("De oude code werkt daarna niet meer.")
        }
        .alert("Mislukt", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .alert("Verstuurd", isPresented: Binding(
            get: { viewModel.inviteSentMessage != nil },
            set: { if !$0 { viewModel.inviteSentMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.inviteSentMessage ?? "")
        }
        .onChange(of: logoPickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await viewModel.uploadLogo(fileName: "logo.jpg", mimeType: "image/jpeg", fileData: data, token: token)
                }
                logoPickerItem = nil
            }
        }
    }

    private var errorState: some View {
        VStack(spacing: BovexaTheme.Space.sm) {
            Text("Kon teamgegevens niet laden.")
                .font(BovexaTheme.TypeStyle.subheadline)
                .foregroundStyle(BovexaTheme.Colors.muted)
            Button("Opnieuw proberen") { Task { await viewModel.load(token: token) } }
                .font(BovexaTheme.TypeStyle.subheadline.weight(.bold))
                .foregroundStyle(BovexaTheme.Colors.accent)
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BovexaTheme.Space.lg) {
                Text("Uitnodigen")
                    .font(BovexaTheme.TypeStyle.title2)
                    .foregroundStyle(BovexaTheme.Colors.ink)
                inviteCard

                Text("Bedrijfsprofiel")
                    .font(BovexaTheme.TypeStyle.title2)
                    .foregroundStyle(BovexaTheme.Colors.ink)
                profileCard
            }
            .padding(BovexaTheme.Space.xl)
            .padding(.bottom, BovexaTheme.Space.tabBarClearance)
        }
    }

    // MARK: - Uitnodigen

    private var inviteCard: some View {
        GlassCard(emphasis: .hero) {
            VStack(alignment: .leading, spacing: BovexaTheme.Space.md) {
                VStack(alignment: .center, spacing: BovexaTheme.Space.xs) {
                    Text("BEDRIJFSCODE")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(BovexaTheme.Colors.accent)
                        .tracking(1.2)
                    Text(viewModel.joinCode)
                        .font(.system(.title, design: .rounded, weight: .heavy))
                        .foregroundStyle(BovexaTheme.Colors.ink)
                }
                .frame(maxWidth: .infinity)

                HStack(spacing: BovexaTheme.Space.sm) {
                    Button(viewModel.copied ? "Gekopieerd" : "Kopieer") { copyCode() }
                        .buttonStyle(.glassSecondaryBrand)
                    Button("Deel") { shareCode() }
                        .buttonStyle(.glassSecondaryBrand)
                    Button {
                        Haptics.warning()
                        showRotateConfirm = true
                    } label: {
                        if viewModel.rotating {
                            ProgressView().tint(BovexaTheme.Colors.accent)
                        } else {
                            Text("Nieuwe code")
                        }
                    }
                    .buttonStyle(.glassSecondaryBrand)
                    .disabled(viewModel.rotating)
                }
                .frame(maxWidth: .infinity)

                HStack(spacing: BovexaTheme.Space.sm) {
                    TextField("collega@voorbeeld.nl", text: $viewModel.inviteEmail)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(BovexaTheme.TypeStyle.body)
                        .padding(.horizontal, BovexaTheme.Space.sm)
                        .frame(minHeight: 40)
                        .background(BovexaTheme.Colors.glass, in: Capsule())
                        .overlay(Capsule().stroke(BovexaTheme.Colors.edge, lineWidth: 1))

                    Button {
                        Haptics.selection()
                        Task { await viewModel.sendInvite(token: token) }
                    } label: {
                        if viewModel.inviteSending {
                            ProgressView().tint(BovexaTheme.Colors.white)
                        } else {
                            Text("Mail")
                        }
                    }
                    .buttonStyle(.glassProminentBrand)
                    .disabled(viewModel.inviteSending || viewModel.inviteEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                logoRow

                if viewModel.full {
                    Text("Bedrijf zit vol — meer plekken komt in een latere versie.")
                        .font(BovexaTheme.TypeStyle.caption)
                        .foregroundStyle(BovexaTheme.Colors.muted)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
    }

    private var logoRow: some View {
        HStack(spacing: BovexaTheme.Space.sm) {
            logoPreview

            PhotosPicker(selection: $logoPickerItem, matching: .images) {
                if viewModel.logoBusy {
                    ProgressView().tint(BovexaTheme.Colors.accent)
                } else {
                    Text((viewModel.org?.logo.isEmpty ?? true) ? "Logo kiezen" : "Logo wijzigen")
                }
            }
            .buttonStyle(.glassSecondaryBrand)
            .disabled(viewModel.logoBusy)

            if let logo = viewModel.org?.logo, !logo.isEmpty {
                Button("Verwijder") {
                    Haptics.selection()
                    Task { await viewModel.removeLogo(token: token) }
                }
                .buttonStyle(.glassSecondaryBrand)
                .disabled(viewModel.logoBusy)
            }
        }
    }

    @ViewBuilder
    private var logoPreview: some View {
        if let org = viewModel.org, !org.logo.isEmpty,
           let url = URL(string: "\(PBEndpoint.base.absoluteString)/api/files/agenda_orgs/\(org.id)/\(org.logo)") {
            AsyncImage(url: url) { $0.resizable().aspectRatio(contentMode: .fit) } placeholder: { Color.clear }
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: BovexaTheme.Radius.sm, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: BovexaTheme.Radius.sm, style: .continuous)
                .fill(BovexaTheme.Colors.glass)
                .frame(width: 40, height: 40)
                .overlay(Image(systemName: "camera").foregroundStyle(BovexaTheme.Colors.muted))
        }
    }

    private func copyCode() {
        Haptics.selection()
        UIPasteboard.general.string = viewModel.joinCode
        viewModel.copied = true
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            viewModel.copied = false
        }
    }

    private func shareCode() {
        Haptics.selection()
        let message = "Doe mee met ons team in Bovexa Flow — bedrijfscode: \(viewModel.joinCode)"
        let activity = UIActivityViewController(activityItems: [message], applicationActivities: nil)
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.keyWindow?.rootViewController?
            .present(activity, animated: true)
    }

    // MARK: - Bedrijfsprofiel

    private var profileCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BovexaTheme.Space.sm) {
                labeledField("Adres", text: $viewModel.address)
                labeledField("Telefoon", text: $viewModel.phone, keyboard: .phonePad)
                labeledField("E-mail", text: $viewModel.email, keyboard: .emailAddress)
                labeledField("Tijdzone", text: $viewModel.timezone)

                Text("STANDAARDDUUR NIEUWE AFSPRAAK")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(BovexaTheme.Colors.accent)
                    .padding(.top, BovexaTheme.Space.xs)
                HStack(spacing: BovexaTheme.Space.md) {
                    Button {
                        Haptics.selection()
                        viewModel.decrementDuration()
                    } label: {
                        Image(systemName: "minus")
                    }
                    .buttonStyle(.glassSecondaryBrand)

                    Text("\(viewModel.defaultDurationMin) min")
                        .font(BovexaTheme.TypeStyle.body.weight(.bold))
                        .foregroundStyle(BovexaTheme.Colors.ink)

                    Button {
                        Haptics.selection()
                        viewModel.incrementDuration()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.glassSecondaryBrand)
                }

                Text("OPENINGSTIJDEN")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(BovexaTheme.Colors.accent)
                    .padding(.top, BovexaTheme.Space.xs)
                ForEach(OpeningHours.dayOrder, id: \.label) { entry in
                    DayHoursRow(label: entry.label, value: viewModel.openingHours[keyPath: entry.key]) { open, close in
                        viewModel.setDayHours(entry.key, open: open, close: close)
                    }
                }

                Button {
                    Haptics.selection()
                    Task { await viewModel.saveProfile(token: token) }
                } label: {
                    if viewModel.savingProfile {
                        ProgressView().tint(BovexaTheme.Colors.white).frame(maxWidth: .infinity)
                    } else {
                        Text("Opslaan").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.glassProminentBrand)
                .padding(.top, BovexaTheme.Space.xs)
            }
        }
    }

    private func labeledField(_ label: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(BovexaTheme.Colors.accent)
            TextField(label, text: text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(keyboard == .emailAddress ? .never : .sentences)
                .autocorrectionDisabled(keyboard == .emailAddress)
                .font(BovexaTheme.TypeStyle.body)
                .padding(.horizontal, BovexaTheme.Space.sm)
                .frame(minHeight: 40)
                .background(BovexaTheme.Colors.glass, in: RoundedRectangle(cornerRadius: BovexaTheme.Radius.sm, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: BovexaTheme.Radius.sm, style: .continuous).stroke(BovexaTheme.Colors.edge, lineWidth: 1))
        }
    }
}

private struct DayHoursRow: View {
    let label: String
    let value: DayHours?
    let onChange: (String, String) -> Void

    @State private var open: String
    @State private var close: String

    init(label: String, value: DayHours?, onChange: @escaping (String, String) -> Void) {
        self.label = label
        self.value = value
        self.onChange = onChange
        _open = State(initialValue: value?.open ?? "")
        _close = State(initialValue: value?.close ?? "")
    }

    var body: some View {
        HStack(spacing: BovexaTheme.Space.sm) {
            Text(label)
                .font(BovexaTheme.TypeStyle.footnote.weight(.bold))
                .foregroundStyle(BovexaTheme.Colors.inkSoft)
                .frame(width: 28, alignment: .leading)
            TextField("09:00", text: $open)
                .multilineTextAlignment(.center)
                .onChange(of: open) { _, newValue in onChange(newValue, close) }
            Text("–").foregroundStyle(BovexaTheme.Colors.muted)
            TextField("17:00", text: $close)
                .multilineTextAlignment(.center)
                .onChange(of: close) { _, newValue in onChange(open, newValue) }
        }
        .font(BovexaTheme.TypeStyle.footnote)
        .foregroundStyle(BovexaTheme.Colors.ink)
    }
}

#Preview {
    NavigationStack {
        TeambeheerView().environmentObject(AuthStore())
    }
}
