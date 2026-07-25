import SwiftUI

/// AI-planner chatscherm — geport uit planner.tsx. Startkaart met voorbeeld-chips,
/// chat-thread, quick-reply-chips, concept-kaarten, "Even kijken…", "Opnieuw proberen",
/// reset. Bevestig-blok (visibility/toewijzen/herinnering/"Zet in agenda") komt in
/// plak 3; mic-knop in plak 4 — de composer hieronder is voorlopig tekst-only.
struct PlannerView: View {
    @StateObject private var viewModel: PlannerViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var input = ""

    private let seed: String?

    private static let examples = [
        "Morgen 15:00 tandarts",
        "Vrijdag 09:30 ketelonderhoud bij De Vries",
        "Volgende week lunch met Oby",
    ]

    init(userId: String, token: String, seed: String? = nil) {
        _viewModel = StateObject(wrappedValue: PlannerViewModel(userId: userId, token: token))
        self.seed = seed
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
        }
        .task {
            viewModel.hydrate()
            if let seed, !seed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, viewModel.thread.isEmpty {
                await viewModel.sendText(seed)
            }
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

    private var composer: some View {
        HStack(alignment: .bottom, spacing: BovexaTheme.Space.sm) {
            TextField("Typ je bericht…", text: $input, axis: .vertical)
                .lineLimit(1...5)
                .font(BovexaTheme.TypeStyle.subheadline)
                .submitLabel(.send)
                .onSubmit(submit)

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
        let text = input
        input = ""
        Task { await viewModel.sendText(text) }
    }
}

#Preview {
    PlannerView(userId: "u1", token: "tok")
}
