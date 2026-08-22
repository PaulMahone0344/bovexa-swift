import SwiftUI

/// Hoe de planner in beeld staat. Als sheet-root brengt hij zijn eigen
/// NavigationStack en sluitkruisje mee; gepusht (vanuit de keuzesheet "Nieuwe
/// afspraak", M12) levert de omliggende stack de balk en de terugknop, en sluit de
/// caller de sheet na een geslaagde bevestiging.
enum PlannerPresentation {
    case sheet
    case pushed
}

/// AI-planner chatscherm — geport uit planner.tsx. Startkaart met voorbeeld-chips,
/// chat-thread, quick-reply-chips, concept-kaarten, "Even kijken…", "Opnieuw proberen",
/// reset, bevestig-blok (zichtbaarheid/toewijzen/herinnering/"Zet in agenda") en een
/// mic-knop in de composer om te dicteren (valkuil J).
struct PlannerView: View {
    @FocusState private var inputFocused: Bool
    @StateObject private var viewModel: PlannerViewModel
    @StateObject private var speech = SpeechToTextService()
    @ObservedObject var memberColors: MemberColors
    @ObservedObject var labelStore: LabelStore
    @Environment(\.dismiss) private var dismiss
    @State private var input = ""
    @State private var speechAlertMessage: String?
    /// Zichtbaarheid, toewijzen, label, contact en herinnering staan standaard dicht.
    /// Uitgeklapt duwden ze "Zet in agenda" ver onder de vouw, terwijl je meestal
    /// niets wilt wijzigen: de planner heeft het al ingevuld.
    @State private var showDetails = false

    private let hasOrg: Bool
    private let org: String
    private let token: String
    private let seed: String?
    private let presentation: PlannerPresentation
    private let onConfirmed: (Date) -> Void

    private static let examples = [
        "Morgen 15:00 tandarts",
        "Vrijdag 09:30 ketelonderhoud bij De Vries",
        "Volgende week lunch met Oby",
    ]

    init(
        userId: String, token: String, org: String?, memberColors: MemberColors, labelStore: LabelStore = LabelStore(),
        seed: String? = nil, presentation: PlannerPresentation = .sheet, onConfirmed: @escaping (Date) -> Void = { _ in }
    ) {
        _viewModel = StateObject(wrappedValue: PlannerViewModel(userId: userId, token: token, org: org))
        self.memberColors = memberColors
        self.labelStore = labelStore
        self.hasOrg = org != nil
        self.org = org ?? ""
        self.token = token
        self.seed = seed
        self.presentation = presentation
        self.onConfirmed = onConfirmed
    }

    /// Setter bewust leeg: hij liep óók vóór "Toch plannen" en maakte `ownEvents`
    /// leeg, waardoor een tweede overlap bij de overige voorstellen niet meer
    /// gemeld werd (4k). De knoppen roepen de viewmodel zelf aan.
    private var overlapPresented: Binding<Bool> {
        Binding(get: { viewModel.overlapEvent != nil }, set: { _ in })
    }

    var body: some View {
        Group {
            switch presentation {
            case .sheet:
                // Sheet-root: eigen stapel, eigen kruisje.
                NavigationStack { screen }
            case .pushed:
                // Gepusht in de keuzesheet: de stapel eromheen levert titelbalk en
                // terugknop. Een tweede NavigationStack zou twee balken tekenen.
                screen
            }
        }
        .task {
            viewModel.hydrate()
            if let seed, !seed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, viewModel.thread.isEmpty {
                await viewModel.sendText(seed)
            }
        }
        .onChange(of: viewModel.confirmedDate) { _, date in
            if let date {
                Haptics.success()
                onConfirmed(date)
                // Alleen als sheet-root sluit de planner zichzelf. Gepusht zou
                // `dismiss()` deze pagina van de stapel halen en de keuzesheet open
                // laten staan; daar sluit de caller de sheet in onConfirmed.
                if presentation == .sheet { dismiss() }
            }
        }
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

    private var screen: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: BovexaTheme.Space.md) {
                            if viewModel.thread.isEmpty {
                                startCard
                            }
                            threadContent
                            if viewModel.ready != nil {
                                confirmBlock
                            }
                            // Anker ná het bevestig-blok: stond het erboven,
                            // dan scrolde het scherm tot net onder de
                            // conceptkaart en viel "Zet in agenda" onder de
                            // vouw — juist de volgende handeling (4k).
                            Color.clear.frame(height: 1).id("bottom")
                        }
                        .padding(BovexaTheme.Space.xl)
                    }
                    .onChange(of: viewModel.thread.count) {
                        withAnimation(.snappy) { proxy.scrollTo("bottom", anchor: .bottom) }
                    }
                    .onChange(of: viewModel.loading) {
                        withAnimation(.snappy) { proxy.scrollTo("bottom", anchor: .bottom) }
                    }
                }
                composer
            }
        }
        .navigationTitle("AI Planner")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !viewModel.thread.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Haptics.selection()
                        // Ook het getypte bericht: dat bleef staan terwijl het
                        // gesprek eromheen verdween (4k).
                        input = ""
                        viewModel.reset()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Nieuw gesprek")
                }
            }
            // Gepusht sluit de omliggende stapel het scherm met een terugknop; een
            // kruisje ernaast zou twee verschillende "weg hier"-knoppen geven.
            if presentation == .sheet {
                SheetCloseButton { dismiss() }
            }
        }
        .alert("Dubbele boeking", isPresented: overlapPresented) {
            Button("Aanpassen", role: .cancel) { viewModel.cancelOverlap() }
            Button("Toch plannen") {
                Task { await viewModel.proceedPastOverlap() }
            }
        } message: {
            if let overlap = viewModel.overlapEvent {
                Text("Je staat al \(EventHelpers.fmtTime(overlap.start))–\(EventHelpers.fmtTime(overlap.end)) op \"\(overlap.title)\". Toch plannen?")
            }
        }
        .alert("Mislukt", isPresented: $viewModel.saveFailedAlert) {
            Button("Oké", role: .cancel) {}
        } message: {
            Text("Kon de afspraak niet opslaan. Probeer het nog een keer.")
        }
    }

    private var startCard: some View {
        GlassCard(emphasis: .hero) {
            VStack(alignment: .leading, spacing: BovexaTheme.Space.md) {
                HStack(spacing: BovexaTheme.Space.md) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: BovexaTheme.Gradients.blue, startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 34, height: 34)
                        Image(systemName: "sparkles")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(BovexaTheme.Colors.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Nieuwe afspraak")
                            .font(BovexaTheme.TypeStyle.title3)
                            .foregroundStyle(BovexaTheme.Colors.ink)
                        Text("Schrijf gewoon wat, wanneer en eventueel waar.")
                            .font(BovexaTheme.TypeStyle.footnote)
                            .foregroundStyle(BovexaTheme.Colors.muted)
                    }
                }

                HStack(spacing: BovexaTheme.Space.sm) {
                    Image(systemName: "square.and.pencil")
                        .foregroundStyle(BovexaTheme.Colors.accent)
                    Text("Bijv. morgen 15:00 tandarts in Amsterdam")
                        .font(BovexaTheme.TypeStyle.footnote.weight(.semibold))
                        .foregroundStyle(BovexaTheme.Colors.inkSoft)
                }
                .padding(.horizontal, BovexaTheme.Space.md)
                .padding(.vertical, BovexaTheme.Space.sm + 2)
                .background(BovexaTheme.Colors.blue.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: BovexaTheme.Radius.md, style: .continuous))

                FlowLayout(spacing: BovexaTheme.Space.sm) {
                    ForEach(Self.examples, id: \.self) { example in
                        Button {
                            Task { await viewModel.sendText(example) }
                        } label: {
                            Text(example)
                                .font(BovexaTheme.TypeStyle.caption.weight(.bold))
                                .foregroundStyle(BovexaTheme.Colors.accent)
                                .padding(.horizontal, BovexaTheme.Space.md)
                                .frame(minHeight: 44)
                                .background(BovexaTheme.Colors.glass)
                                .clipShape(Capsule())
                                .overlay(Capsule().strokeBorder(BovexaTheme.Colors.edgeSoft, lineWidth: 1))
                        }
                        .disabled(viewModel.loading)
                        .opacity(viewModel.loading ? 0.5 : 1)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var threadContent: some View {
        VStack(alignment: .leading, spacing: BovexaTheme.Space.md) {
            ForEach(viewModel.thread) { item in
                threadRow(item, isLast: item.id == viewModel.thread.last?.id)
            }

            if viewModel.loading {
                HStack(spacing: BovexaTheme.Space.sm) {
                    ProgressView().tint(BovexaTheme.Colors.accent)
                    Text("Even kijken…")
                        .font(BovexaTheme.TypeStyle.footnote.weight(.semibold))
                        .foregroundStyle(BovexaTheme.Colors.muted)
                }
                .padding(.leading, BovexaTheme.Space.xs)
            }
        }
    }

    @ViewBuilder
    private func threadRow(_ item: ThreadItem, isLast: Bool) -> some View {
        switch item.kind {
        case .user:
            ChatBubbleView(role: .user, text: item.text)
        case .question:
            VStack(alignment: .leading, spacing: BovexaTheme.Space.sm) {
                ChatBubbleView(role: .ai, text: item.text)
                QuickReplyChipsView(options: item.options, disabled: viewModel.loading || !isLast) { option in
                    Task { await viewModel.chooseOption(option) }
                }
            }
        case .proposal:
            VStack(alignment: .leading, spacing: BovexaTheme.Space.sm) {
                ChatBubbleView(role: .ai, text: item.text)
                ForEach(Array(item.appointments.enumerated()), id: \.offset) { _, appointment in
                    ConceptCardView(appointment: appointment)
                }
            }
        case .error:
            VStack(alignment: .leading, spacing: BovexaTheme.Space.sm) {
                ChatBubbleView(role: .ai, text: item.text, tone: .error)
                if isLast {
                    Button("Opnieuw proberen") {
                        Task { await viewModel.retry() }
                    }
                    .buttonStyle(.glassSecondaryBrand)
                    .tint(BovexaTheme.Colors.accent)
                    .disabled(viewModel.loading)
                }
            }
        }
    }

    @ViewBuilder
    private var confirmBlock: some View {
        VStack(alignment: .leading, spacing: BovexaTheme.Space.md) {
            detailsToggle

            Button {
                Task { await viewModel.confirm() }
            } label: {
                // Frame ín het label, ook in de ProgressView-tak: buiten de Button
                // is de pil zo breed als zijn tekst en raakt alleen de pil, en
                // tijdens opslaan kromp hij naar spinner-breedte.
                if viewModel.saving {
                    ProgressView().tint(BovexaTheme.Colors.white).frame(maxWidth: .infinity)
                } else {
                    Text("Zet in agenda").frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.glassProminentBrand)
            .disabled(viewModel.saving)
        }
        // De vijf blokken uitklappen ín het gesprek duwde "Zet in agenda" een half
        // scherm naar beneden, precies wanneer je die knop nodig hebt. In een eigen
        // sheet blijft de bevestiging in beeld en houden de pickers hun ruimte.
        .sheet(isPresented: $showDetails) { detailsSheet }
    }

    private var detailsSheet: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    detailPickers
                        .padding(BovexaTheme.Space.xl)
                }
            }
            .navigationTitle("Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Klaar") { showDetails = false }
                        .font(BovexaTheme.TypeStyle.body.weight(.semibold))
                }
            }
        }
        // Medium is genoeg voor zichtbaarheid en toewijzen; wie bij contact of
        // herinnering moet zijn trekt hem omhoog.
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    /// De rij met de chevron. Toont samengevat wat er onder zit, zodat dichtklappen
    /// geen informatie kost.
    private var detailsToggle: some View {
        Button {
            Haptics.selection()
            showDetails = true
        } label: {
            HStack(spacing: BovexaTheme.Space.sm) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(BovexaTheme.Colors.accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Details")
                        .font(BovexaTheme.TypeStyle.subheadline.weight(.bold))
                        .foregroundStyle(BovexaTheme.Colors.ink)
                    if !detailsSummary.isEmpty {
                        Text(detailsSummary)
                            .font(BovexaTheme.TypeStyle.caption)
                            .foregroundStyle(BovexaTheme.Colors.muted)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: BovexaTheme.Space.sm)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(BovexaTheme.Colors.muted)
            }
            .padding(.horizontal, BovexaTheme.Space.md)
            .padding(.vertical, BovexaTheme.Space.sm + 2)
            .frame(maxWidth: .infinity)
            .background(BovexaTheme.Colors.glass)
            .clipShape(RoundedRectangle(cornerRadius: BovexaTheme.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: BovexaTheme.Radius.md, style: .continuous)
                    .strokeBorder(BovexaTheme.Colors.edge, lineWidth: 1)
            )
            // Glas telt niet mee voor hit-testing; zonder dit is alleen de tekst raakbaar.
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Details aanpassen")
    }

    private var detailsSummary: String {
        PlannerDetailsSummary.text(
            visibility: hasOrg ? viewModel.visibility : nil,
            companyName: memberColors.orgName,
            assigneeCount: hasOrg ? viewModel.assignee.count : 0,
            labelName: hasOrg ? labelStore.label(for: viewModel.label)?.naam : nil,
            contactName: hasOrg ? viewModel.contactNaam : nil,
            reminderMin: viewModel.reminderMin
        )
    }

    @ViewBuilder
    private var detailPickers: some View {
        VStack(alignment: .leading, spacing: BovexaTheme.Space.md) {
            if hasOrg {
                VisibilityPickerView(value: viewModel.visibility, companyName: memberColors.orgName ?? "Bedrijf") { value in
                    viewModel.visibility = value
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: BovexaTheme.Space.sm) {
                        Text("TOEGEWEZEN AAN")
                            .font(BovexaTheme.TypeStyle.caption.weight(.bold))
                            .foregroundStyle(BovexaTheme.Colors.accent)
                            .tracking(0.3)
                        AssigneePickerView(members: memberColors.members, currentUserId: viewModel.ownerId, selectedIds: $viewModel.assignee)
                        if viewModel.visibility == "private" && !viewModel.assignee.isEmpty {
                            Text("Privé betekent nu: alleen jij + toegewezenen.")
                                .font(BovexaTheme.TypeStyle.caption)
                                .foregroundStyle(BovexaTheme.Colors.muted)
                        }
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: BovexaTheme.Space.sm) {
                        Text("LABEL")
                            .font(BovexaTheme.TypeStyle.caption.weight(.bold))
                            .foregroundStyle(BovexaTheme.Colors.accent)
                            .tracking(0.3)
                        LabelPickerView(labelStore: labelStore, selectedLabelId: $viewModel.label, org: org, token: token)
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: BovexaTheme.Space.sm) {
                        Text("CONTACT")
                            .font(BovexaTheme.TypeStyle.caption.weight(.bold))
                            .foregroundStyle(BovexaTheme.Colors.accent)
                            .tracking(0.3)
                        ContactPickerView(
                            selectedContactId: $viewModel.contactId,
                            existingKlantNaam: viewModel.ready?.first?.klantNaam ?? "",
                            userId: viewModel.ownerId, token: token,
                            onSelect: { viewModel.selectContact($0) }
                        )
                    }
                }
            }

            ReminderChipsView(minutesBefore: $viewModel.reminderMin)
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: BovexaTheme.Space.sm) {
            TextField("Typ je bericht…", text: $input, axis: .vertical)
                .keyboardDone(focused: $inputFocused)
                .lineLimit(1...5)
                .font(BovexaTheme.TypeStyle.subheadline)
                // Geen .submitLabel(.send)/.onSubmit: in een meerregelig veld maakt
                // Return een nieuwe regel en vuurt onSubmit niet. De toets heette
                // dan wel "Verstuur" maar deed iets anders (4k) — de pijlknop is de
                // enige verstuurder.

            if speech.available {
                MicButtonView(listening: speech.listening, size: 34) {
                    Task { await speech.toggle() }
                }
            }

            Button(action: submit) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(BovexaTheme.Colors.white)
                    .frame(width: 38, height: 38)
                    .background(LinearGradient(colors: BovexaTheme.Gradients.blue, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .clipShape(Circle())
                    // Cirkel blijft 38pt, raakvlak 44.
                    .minTapTarget()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Verstuur")
            .disabled(!canSend)
            .opacity(canSend ? 1 : 0.5)
        }
        .padding(.horizontal, BovexaTheme.Space.md)
        .padding(.vertical, BovexaTheme.Space.sm)
        .background(BovexaTheme.Colors.glass)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(BovexaTheme.Colors.edge, lineWidth: 1))
        .padding(BovexaTheme.Space.md)
    }

    private var canSend: Bool {
        !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !viewModel.loading
    }

    private func submit() {
        guard canSend else { return }
        if speech.listening { speech.stop() }
        let text = input
        input = ""
        Task { await viewModel.sendText(text) }
    }
}

#Preview {
    PlannerView(userId: "u1", token: "tok", org: "org1", memberColors: MemberColors())
}
