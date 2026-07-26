import SwiftUI

/// AI-planner chatscherm — geport uit planner.tsx. Startkaart met voorbeeld-chips,
/// chat-thread, quick-reply-chips, concept-kaarten, "Even kijken…", "Opnieuw proberen",
/// reset, bevestig-blok (zichtbaarheid/toewijzen/herinnering/"Zet in agenda") en een
/// mic-knop in de composer om te dicteren (valkuil J).
struct PlannerView: View {
    @StateObject private var viewModel: PlannerViewModel
    @StateObject private var speech = SpeechToTextService()
    @ObservedObject var memberColors: MemberColors
    @ObservedObject var labelStore: LabelStore
    @Environment(\.dismiss) private var dismiss
    @State private var input = ""
    @State private var speechAlertMessage: String?

    private let hasOrg: Bool
    private let org: String
    private let token: String
    private let seed: String?
    private let onConfirmed: (Date) -> Void

    private static let examples = [
        "Morgen 15:00 tandarts",
        "Vrijdag 09:30 ketelonderhoud bij De Vries",
        "Volgende week lunch met Oby",
    ]

    init(
        userId: String, token: String, org: String?, memberColors: MemberColors, labelStore: LabelStore = LabelStore(),
        seed: String? = nil, onConfirmed: @escaping (Date) -> Void = { _ in }
    ) {
        _viewModel = StateObject(wrappedValue: PlannerViewModel(userId: userId, token: token, org: org))
        self.memberColors = memberColors
        self.labelStore = labelStore
        self.hasOrg = org != nil
        self.org = org ?? ""
        self.token = token
        self.seed = seed
        self.onConfirmed = onConfirmed
    }

    private var overlapPresented: Binding<Bool> {
        Binding(get: { viewModel.overlapEvent != nil }, set: { if !$0 { viewModel.cancelOverlap() } })
    }

    var body: some View {
        NavigationStack {
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
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                }
                if !viewModel.thread.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            Haptics.selection()
                            viewModel.reset()
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
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
                dismiss()
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

    private var startCard: some View {
        GlassCard(emphasis: .hero) {
            VStack(alignment: .leading, spacing: BovexaTheme.Space.md) {
                HStack(spacing: BovexaTheme.Space.md) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: BovexaTheme.Gradients.teal, startPoint: .topLeading, endPoint: .bottomTrailing))
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
                .background(BovexaTheme.Colors.teal.opacity(0.12))
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
                                .padding(.vertical, BovexaTheme.Space.sm)
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
        Color.clear.frame(height: 1).id("bottom")
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
                            userId: viewModel.ownerId, token: token
                        )
                    }
                }
            }

            ReminderChipsView(minutesBefore: $viewModel.reminderMin)

            Button {
                Task { await viewModel.confirm() }
            } label: {
                if viewModel.saving {
                    ProgressView().tint(BovexaTheme.Colors.white)
                } else {
                    Text("Zet in agenda")
                }
            }
            .buttonStyle(.glassProminentBrand)
            .frame(maxWidth: .infinity)
            .disabled(viewModel.saving)
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: BovexaTheme.Space.sm) {
            TextField("Typ je bericht…", text: $input, axis: .vertical)
                .lineLimit(1...5)
                .font(BovexaTheme.TypeStyle.subheadline)
                .submitLabel(.send)
                .onSubmit(submit)

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
                    .background(LinearGradient(colors: BovexaTheme.Gradients.teal, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .clipShape(Circle())
            }
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
