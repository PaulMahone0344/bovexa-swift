import SwiftUI

/// Vrienden-scherm: iemand uitnodigen op e-mailadres, inkomende verzoeken
/// beantwoorden en zien met wie je gekoppeld bent. De koppeling is wat afspraken
/// naar elkaar sturen mogelijk maakt — zonder koppeling kan niemand ongevraagd
/// iets in jouw agenda zetten.
struct VriendenView: View {
    @StateObject private var viewModel: VriendenViewModel
    @Environment(\.dismiss) private var dismiss

    init(token: String) {
        _viewModel = StateObject(wrappedValue: VriendenViewModel(token: token))
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: BovexaTheme.Space.lg) {
                    uitnodigenSectie

                    if !viewModel.inkomend.isEmpty {
                        inkomendSectie
                    }
                    if !viewModel.uitgaand.isEmpty {
                        uitgaandSectie
                    }

                    vriendenSectie
                }
                .padding(BovexaTheme.Space.xl)
                .padding(.bottom, BovexaTheme.Space.tabBarClearance)
            }
        }
        .navigationTitle("Vrienden")
        .navigationBarTitleDisplayMode(.large)
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .alert("Gelukt", isPresented: Binding(
            get: { viewModel.bevestiging != nil },
            set: { if !$0 { viewModel.bevestiging = nil } }
        )) {
            Button("Oké", role: .cancel) { viewModel.bevestiging = nil }
        } message: {
            Text(viewModel.bevestiging ?? "")
        }
        .alert("Er ging iets mis", isPresented: Binding(
            get: { viewModel.foutmelding != nil },
            set: { if !$0 { viewModel.foutmelding = nil } }
        )) {
            Button("Oké", role: .cancel) { viewModel.foutmelding = nil }
        } message: {
            Text(viewModel.foutmelding ?? "")
        }
    }

    private var uitnodigenSectie: some View {
        VStack(alignment: .leading, spacing: BovexaTheme.Space.sm) {
            kop("IEMAND UITNODIGEN")

            GlassCard {
                VStack(alignment: .leading, spacing: BovexaTheme.Space.sm) {
                    TextField("naam@voorbeeld.nl", text: $viewModel.email)
                        .textFieldStyle(.plain)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .padding(.horizontal, BovexaTheme.Space.md)
                        .frame(minHeight: 44)
                        .background(BovexaTheme.Colors.glass)
                        .clipShape(RoundedRectangle(cornerRadius: BovexaTheme.Radius.md, style: .continuous))

                    Text("Heeft die persoon al een account, dan krijgt hij het verzoek in de app. Zo niet, dan gaat er een uitnodiging per mail.")
                        .font(BovexaTheme.TypeStyle.footnote)
                        .foregroundStyle(BovexaTheme.Colors.inkSoft)

                    Button {
                        Haptics.selection()
                        Task { await viewModel.nodigUit() }
                    } label: {
                        if viewModel.versturen {
                            ProgressView().tint(BovexaTheme.Colors.white)
                        } else {
                            Label("Verzoek versturen", systemImage: "paperplane.fill")
                        }
                    }
                    .buttonStyle(.glassProminentBrand)
                    .disabled(!viewModel.kanVersturen)
                }
            }
        }
    }

    private var inkomendSectie: some View {
        VStack(alignment: .leading, spacing: BovexaTheme.Space.sm) {
            kop("WACHT OP JOU")

            ForEach(viewModel.inkomend) { verzoek in
                GlassCard {
                    VStack(alignment: .leading, spacing: BovexaTheme.Space.sm) {
                        persoonsregel(naam: verzoek.naam, email: verzoek.email)

                        HStack(spacing: BovexaTheme.Space.sm) {
                            Button("Accepteren") {
                                Haptics.selection()
                                Task { await viewModel.beantwoord(verzoek, accepteren: true) }
                            }
                            .buttonStyle(.glassProminentBrand)

                            Button("Weigeren") {
                                Haptics.selection()
                                Task { await viewModel.beantwoord(verzoek, accepteren: false) }
                            }
                            .buttonStyle(.glassSecondaryDanger)
                        }
                        .disabled(viewModel.beantwoordId != nil)
                    }
                }
            }
        }
    }

    private var uitgaandSectie: some View {
        VStack(alignment: .leading, spacing: BovexaTheme.Space.sm) {
            kop("VERSTUURD")

            GlassCard(padding: BovexaTheme.Space.xs, emphasis: .quiet) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(viewModel.uitgaand.enumerated()), id: \.element.id) { index, verzoek in
                        if index > 0 {
                            Divider().overlay(BovexaTheme.Colors.edge)
                        }
                        HStack {
                            persoonsregel(naam: verzoek.naam, email: verzoek.email)
                            Spacer(minLength: BovexaTheme.Space.sm)
                            Text("Wacht")
                                .font(BovexaTheme.TypeStyle.caption.weight(.bold))
                                .foregroundStyle(BovexaTheme.Colors.inkSoft)
                        }
                        .padding(.vertical, BovexaTheme.Space.xs)
                        .padding(.horizontal, BovexaTheme.Space.sm)
                    }
                }
            }
        }
    }

    private var vriendenSectie: some View {
        VStack(alignment: .leading, spacing: BovexaTheme.Space.sm) {
            kop("GEKOPPELD")

            if viewModel.loading {
                ProgressView().tint(BovexaTheme.Colors.blue)
                    .frame(maxWidth: .infinity)
            } else if viewModel.vrienden.isEmpty {
                EmptyStateView(
                    systemImage: "person.2",
                    text: "Nog niemand. Nodig een collega uit op zijn e-mailadres; daarna kunnen jullie elkaar afspraken sturen.",
                    surface: .background
                )
            } else {
                GlassCard(padding: BovexaTheme.Space.xs) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(viewModel.vrienden.enumerated()), id: \.element.id) { index, vriend in
                            if index > 0 {
                                Divider().overlay(BovexaTheme.Colors.edge)
                            }
                            HStack {
                                persoonsregel(naam: vriend.naam, email: vriend.email)
                                Spacer(minLength: BovexaTheme.Space.sm)
                                Button {
                                    Haptics.selection()
                                    Task { await viewModel.verwijder(vriend) }
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundStyle(BovexaTheme.Colors.danger)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Koppeling met \(vriend.naam) opheffen")
                            }
                            .padding(.vertical, BovexaTheme.Space.xs)
                            .padding(.horizontal, BovexaTheme.Space.sm)
                        }
                    }
                }
            }
        }
    }

    private func persoonsregel(naam: String, email: String) -> some View {
        HStack(spacing: BovexaTheme.Space.sm) {
            AvatarView(initial: String((naam.isEmpty ? email : naam).prefix(1)).uppercased(), url: nil, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(naam.isEmpty ? email : naam)
                    .font(BovexaTheme.TypeStyle.subheadline.weight(.semibold))
                    .foregroundStyle(BovexaTheme.Colors.ink)
                if !naam.isEmpty {
                    Text(email)
                        .font(BovexaTheme.TypeStyle.footnote)
                        .foregroundStyle(BovexaTheme.Colors.inkSoft)
                }
            }
        }
    }

    private func kop(_ tekst: String) -> some View {
        Text(tekst)
            .font(BovexaTheme.TypeStyle.caption.weight(.bold))
            .foregroundStyle(BovexaTheme.Colors.accent)
            .tracking(0.3)
    }
}
