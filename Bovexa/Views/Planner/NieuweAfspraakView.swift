import SwiftUI

/// "Nieuwe afspraak" (M12, herzien 22 aug): het handmatige formulier ís de pagina,
/// met daarboven één regel voor de AI-route.
///
/// Hier stonden eerst twee gelijkwaardige keuzekaarten (MET AI / HANDMATIG). Zelf
/// invullen is de route die je het vaakst neemt, en die kostte daardoor een tik
/// extra op een scherm dat verder niets deed. De AI-route levert niets in: het
/// tekstveld met microfoon staat er nog, nu bovenaan, dus typen of inspreken kan
/// nog steeds meteen.
///
/// Waarom nog steeds één sheet en geen twee knoppen in de plan-pill: de pill is al
/// vol, en de drie ingangen (pill, dagsheet, leeg uur) zouden anders elk dezelfde
/// twee knoppen moeten tekenen.
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

    /// De AI-route wordt op het formulier gepusht: terug leidt naar het formulier,
    /// het kruisje sluit alles.
    private enum Route: Hashable {
        case planner(String?)
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: BovexaTheme.Space.lg) {
                        aiStrip
                        formulier
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
                }
            }
        }
        // Valkuil D: bovenaan staat een tekstveld. Op een halve sheet duwt het
        // toetsenbord het formulier eronder volledig uit beeld.
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

    // MARK: - AI-regel boven het formulier

    /// Bewust één regel hoog en zonder eigen knoppenrij: dit is de afslag, niet de
    /// hoofdweg. Zelfde vorm als de plan-pill in de Agenda (veld + microfoon +
    /// ✨-knop), zodat het herkenbaar dezelfde ingang is.
    private var aiStrip: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BovexaTheme.Space.sm) {
                HStack(spacing: BovexaTheme.Space.sm) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: BovexaTheme.Gradients.blue, startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 28, height: 28)
                        Image(systemName: "sparkles")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(BovexaTheme.Colors.white)
                    }
                    Text("Laat AI het invullen")
                        .font(BovexaTheme.TypeStyle.subheadline.weight(.semibold))
                        .foregroundStyle(BovexaTheme.Colors.ink)
                    Spacer(minLength: 0)
                }

                HStack(spacing: BovexaTheme.Space.sm) {
                    TextField("morgen 10:00 keuken bij Daan", text: $input)
                        .font(BovexaTheme.TypeStyle.subheadline)
                        .foregroundStyle(BovexaTheme.Colors.ink)
                        .submitLabel(.send)
                        // Geen keyboardDone: eenregelig veld, Return verstuurt al.
                        // Het formulier eronder heeft zelf een meerregelig
                        // notitieveld mét die knop; twee toetsenbord-toolbars in
                        // dezelfde hiërarchie laten er één achter op het scherm.
                        .focused($fieldFocused)
                        .onSubmit(openPlanner)

                    if speech.available {
                        MicButtonView(listening: speech.listening, size: 34) {
                            Task { await speech.toggle() }
                        }
                    }

                    Button(action: openPlanner) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(BovexaTheme.Colors.white)
                            .frame(width: 34, height: 34)
                            .background(LinearGradient(colors: BovexaTheme.Gradients.blue, startPoint: .topLeading, endPoint: .bottomTrailing))
                            .clipShape(Circle())
                            .minTapTarget()
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Plannen met AI")
                }
                .padding(.horizontal, BovexaTheme.Space.md)
                .padding(.vertical, BovexaTheme.Space.xs)
                .background(BovexaTheme.Colors.glass)
                .overlay(
                    RoundedRectangle(cornerRadius: BovexaTheme.Radius.md, style: .continuous)
                        .strokeBorder(BovexaTheme.Colors.edge, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: BovexaTheme.Radius.md, style: .continuous))
            }
        }
    }

    // MARK: - het formulier

    private var formulier: some View {
        EventEditorView(
            seed: seed, currentUserId: userId, org: org ?? "",
            companyName: memberColors.orgName ?? "Bedrijf", token: token,
            members: memberColors.members, labelStore: labelStore,
            defaultDurationMin: defaultDurationMin,
            // Het formulier is nu de eerste pagina, dus Annuleren sluit de sheet in
            // plaats van een stap terug te gaan.
            onCancel: { dismiss() },
            onSaved: { created in
                // Haptics.success() staat al in EventEditorView.
                onConfirmed(created.start)
                dismiss()
            }
        )
    }

    // MARK: - de AI-route

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
