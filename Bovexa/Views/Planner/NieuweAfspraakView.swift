import SwiftUI

/// Keuzesheet "Nieuwe afspraak" (M12): twee gelijkwaardige kaarten — MET AI (met
/// een eigen tekstveld en microfoon, zodat de AI-route géén extra tik kost) en
/// HANDMATIG (het bestaande formulier in create-modus).
///
/// Waarom één sheet en niet twee knoppen in de plan-pill: de pill is al vol, en de
/// drie ingangen (pill, dagsheet, leeg uur) zouden anders elk dezelfde twee knoppen
/// moeten tekenen. Deze sheet vertelt bovendien in woorden wat de app kan — dat was
/// tot nu toe onzichtbaar.
struct NieuweAfspraakView: View {
    /// Waar de gebruiker vandaan kwam: een dag, een leeg uur, of niets.
    let seed: NieuweAfspraakSeed
    let userId: String
    let token: String
    let org: String?
    @ObservedObject var memberColors: MemberColors
    @ObservedObject var labelStore: LabelStore
    /// Standaardduur van het bedrijf voor het handmatige formulier; valt terug op
    /// `EventEditorViewModel.fallbackDurationMin` als het bedrijf er geen heeft.
    var defaultDurationMin: Int = EventEditorViewModel.fallbackDurationMin
    /// Datum van de zojuist gemaakte afspraak — de Agenda springt daarheen en laadt
    /// opnieuw. Zonder dit staat een nieuwe afspraak er pas na een herstart.
    let onConfirmed: (Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var speech = SpeechToTextService()
    @FocusState private var fieldFocused: Bool
    @State private var input = ""
    @State private var path: [Route] = []
    @State private var speechAlertMessage: String?

    /// Beide routes worden gepusht in dezelfde stapel: terug leidt naar de keuze,
    /// het kruisje sluit alles.
    private enum Route: Hashable {
        case planner(String?)
        case handmatig
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: BovexaTheme.Space.lg) {
                        aiCard
                        handmatigCard
                    }
                    .padding(BovexaTheme.Space.xl)
                }
            }
            .navigationTitle("Nieuwe afspraak")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                SheetCloseButton { dismiss() }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .planner(let sentence):
                    plannerPage(sentence: sentence)
                case .handmatig:
                    handmatigPage
                }
            }
        }
        // Valkuil D: de AI-kaart heeft een tekstveld. Op een halve sheet duwt het
        // toetsenbord de handmatig-kaart volledig uit beeld.
        .presentationDetents([.large])
        .onChange(of: speech.transcript) { _, transcript in
            if !transcript.isEmpty { input = transcript }
        }
        .onChange(of: speech.error) { _, error in
            if let error { speechAlertMessage = error }
        }
        .alert("Spraak", isPresented: Binding(get: { speechAlertMessage != nil }, set: { if !$0 { speechAlertMessage = nil } })) {
            Button("Oké", role: .cancel) {}
        } message: {
            Text(speechAlertMessage ?? "")
        }
    }

    // MARK: - kaarten

    private var aiCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BovexaTheme.Space.md) {
                cardHeading(
                    icon: "sparkles",
                    title: "Met AI",
                    subtitle: "Typ of spreek: “morgen 10:00 keuken bij Daan”."
                )

                HStack(spacing: BovexaTheme.Space.sm) {
                    TextField("Typ of spreek een planning", text: $input)
                        .font(BovexaTheme.TypeStyle.subheadline)
                        .foregroundStyle(BovexaTheme.Colors.ink)
                        .submitLabel(.send)
                        .keyboardDone(focused: $fieldFocused)
                        .onSubmit(openPlanner)

                    if speech.available {
                        MicButtonView(listening: speech.listening, size: 36) {
                            Task { await speech.toggle() }
                        }
                    }
                }
                .padding(.horizontal, BovexaTheme.Space.md)
                .padding(.vertical, BovexaTheme.Space.xs)
                .background(BovexaTheme.Colors.glass)
                .overlay(
                    RoundedRectangle(cornerRadius: BovexaTheme.Radius.md, style: .continuous)
                        .strokeBorder(BovexaTheme.Colors.edge, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: BovexaTheme.Radius.md, style: .continuous))

                Button(action: openPlanner) {
                    // Opmaak ín de label-closure (M11 patroon A): buiten de Button
                    // tekent de pil wel breed, maar raakt hij alleen zijn tekst.
                    Label("Plannen met AI", systemImage: "arrow.right")
                        .labelStyle(.titleAndIcon)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminentBrand)
            }
        }
    }

    private var handmatigCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BovexaTheme.Space.md) {
                cardHeading(
                    icon: "square.and.pencil",
                    title: "Handmatig",
                    subtitle: "Vul datum, tijd en details zelf in."
                )

                Button {
                    Haptics.selection()
                    fieldFocused = false
                    path.append(.handmatig)
                } label: {
                    Text("Zelf invullen")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassSecondaryBrand)
            }
        }
    }

    private func cardHeading(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: BovexaTheme.Space.md) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: BovexaTheme.Gradients.blue, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(BovexaTheme.Colors.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(BovexaTheme.TypeStyle.title3)
                    .foregroundStyle(BovexaTheme.Colors.ink)
                Text(subtitle)
                    .font(BovexaTheme.TypeStyle.footnote)
                    .foregroundStyle(BovexaTheme.Colors.muted)
            }
        }
    }

    // MARK: - de twee routes

    private func plannerPage(sentence: String?) -> some View {
        PlannerView(
            userId: userId, token: token, org: org, memberColors: memberColors, labelStore: labelStore,
            seed: sentence, presentation: .pushed,
            onConfirmed: { date in
                onConfirmed(date)
                dismiss()
            }
        )
    }

    private var handmatigPage: some View {
        ZStack {
            AppBackground()
            ScrollView {
                EventEditorView(
                    seed: seed, currentUserId: userId, org: org ?? "",
                    companyName: memberColors.orgName ?? "Bedrijf", token: token,
                    members: memberColors.members, labelStore: labelStore,
                    defaultDurationMin: defaultDurationMin,
                    onCancel: { if !path.isEmpty { path.removeLast() } },
                    onSaved: { created in
                        // Haptics.success() staat al in EventEditorView.
                        onConfirmed(created.start)
                        dismiss()
                    }
                )
                .padding(BovexaTheme.Space.xl)
            }
        }
        .navigationTitle("Zelf invullen")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Getypte of gesproken tekst wint van de dag waar de gebruiker vandaan kwam;
    /// is het veld leeg, dan gaat de dag/het uur alsnog als zin mee (`withText`).
    private func openPlanner() {
        Haptics.selection()
        if speech.listening { speech.stop() }
        // Eerst de focus loslaten, dán navigeren: een veld dat focus houdt terwijl
        // het uit beeld schuift, laat het toetsenbord over de volgende pagina staan
        // (les van 6 aug in PlannerEntryPillView).
        fieldFocused = false
        let sentence = seed.withText(input).plannerSeed()
        input = ""
        path.append(.planner(sentence))
    }
}

#Preview {
    NieuweAfspraakView(
        seed: .empty, userId: "u1", token: "tok", org: "org1",
        memberColors: MemberColors(), labelStore: LabelStore(), onConfirmed: { _ in }
    )
}
