import SwiftUI

/// Meldingen: toewijzingen die op jouw akkoord wachten + bedrijfsmededelingen
/// (valkuil D). Geport uit meldingen.tsx. Plus-knop alleen admin/manager (valkuil E),
/// lang indrukken op je eigen mededeling verwijdert 'm.
struct MeldingenView: View {
    @FocusState private var composeFocused: Bool
    @StateObject private var viewModel: MeldingenViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var deleteTarget: Notice?

    init(userId: String, orgId: String?, token: String) {
        _viewModel = StateObject(wrappedValue: MeldingenViewModel(userId: userId, orgId: orgId, token: token))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: BovexaTheme.Space.lg) {
                        if !viewModel.loaded {
                            // Was leeg tot alles binnen was; de plus-knop verscheen
                            // met vertraging en het scherm leek kapot (4h).
                            ProgressView()
                                .tint(BovexaTheme.Colors.blue)
                                .frame(maxWidth: .infinity)
                                .padding(.top, BovexaTheme.Space.xl)
                        }

                        if viewModel.loadFailed {
                            LoadFailedNote(surface: .background)
                        }

                        if viewModel.canPost {
                            composeSection
                        }

                        if !viewModel.pending.isEmpty {
                            pendingSection
                        }

                        if !viewModel.expired.isEmpty {
                            expiredSection
                        }

                        if viewModel.isEmpty, !viewModel.loadFailed {
                            EmptyStateView(systemImage: "bell", text: "Hier verschijnen mededelingen van je team en toewijzingen die op je akkoord wachten.", surface: .background)
                        }

                        if !viewModel.notices.isEmpty {
                            noticesSection
                        }
                    }
                    .padding(BovexaTheme.Space.xl)
                    // Sheet, dus geen tabbalk eronder: tabBarClearance (104) liet hier
                    // een gat achter (5c).
                    .padding(.bottom, BovexaTheme.Space.xl)
                }
                // Naar beneden vegen sluit het toetsenbord; anders bleef het staan
                // over de knoppen heen.
                .scrollDismissesKeyboard(.interactively)
                .refreshable { await viewModel.load() }
            }
            .navigationTitle("Meldingen")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "chevron.left") }
                        .accessibilityLabel("Sluiten")
                }
                if viewModel.canPost {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            Haptics.selection()
                            withAnimation(.snappy) { viewModel.composeOpen.toggle() }
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel(viewModel.composeOpen ? "Invoer sluiten" : "Nieuwe mededeling")
                    }
                }
            }
        }
        .task { await viewModel.load() }
        .alert("Mislukt", isPresented: Binding(get: { viewModel.postFailedMessage != nil }, set: { if !$0 { viewModel.postFailedMessage = nil } })) {
            Button("Oké", role: .cancel) {}
        } message: {
            Text(viewModel.postFailedMessage ?? "")
        }
        .alert("Mislukt", isPresented: $viewModel.respondFailedAlert) {
            Button("Oké", role: .cancel) {}
        } message: {
            Text("Kon je antwoord niet opslaan.")
        }
        .alert("Mislukt", isPresented: Binding(get: { viewModel.deleteFailedMessage != nil }, set: { if !$0 { viewModel.deleteFailedMessage = nil } })) {
            Button("Oké", role: .cancel) {}
        } message: {
            Text(viewModel.deleteFailedMessage ?? "")
        }
        .alert("Mededeling verwijderen", isPresented: Binding(get: { deleteTarget != nil }, set: { if !$0 { deleteTarget = nil } })) {
            Button("Annuleren", role: .cancel) {}
            Button("Verwijder", role: .destructive) {
                if let notice = deleteTarget {
                    Task { await viewModel.deleteNotice(notice) }
                }
            }
        } message: {
            Text("Weet je het zeker?")
        }
    }

    /// Alleen tekenen als het invoerblok open is. Stond de `GlassCard` erbuiten,
    /// dan zag een admin een leeg glasvlakje zweven zolang hij de plus niet had
    /// aangetikt.
    @ViewBuilder
    private var composeSection: some View {
        if viewModel.composeOpen {
            GlassCard(emphasis: .quiet) {
                VStack(alignment: .leading, spacing: BovexaTheme.Space.sm) {
                    Text("Nieuwe mededeling")
                        .font(BovexaTheme.TypeStyle.headline)
                        .foregroundStyle(BovexaTheme.Colors.ink)
                    TextField("Titel (optioneel)", text: $viewModel.composeTitle)
                        .textFieldStyle(.plain)
                        .padding(BovexaTheme.Space.sm)
                        .background(BovexaTheme.Colors.glassSoft)
                        .clipShape(RoundedRectangle(cornerRadius: BovexaTheme.Radius.sm, style: .continuous))
                    TextField("Bericht voor het hele team…", text: $viewModel.composeBody, axis: .vertical)
                        .keyboardDone(focused: $composeFocused)
                        .lineLimit(3...6)
                        .textFieldStyle(.plain)
                        .padding(BovexaTheme.Space.sm)
                        .background(BovexaTheme.Colors.glassSoft)
                        .clipShape(RoundedRectangle(cornerRadius: BovexaTheme.Radius.sm, style: .continuous))
                    Button {
                        Task {
                            await viewModel.submit()
                            if viewModel.postFailedMessage == nil { Haptics.success() }
                        }
                    } label: {
                        if viewModel.posting {
                            ProgressView().tint(BovexaTheme.Colors.white).frame(maxWidth: .infinity)
                        } else {
                            Text("Plaatsen").frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.glassProminentBrand)
                    .disabled(!viewModel.canSubmit)
                }
            }
        }
    }

    private var pendingSection: some View {
        VStack(alignment: .leading, spacing: BovexaTheme.Space.sm) {
            Text("WACHT OP JOUW AKKOORD")
                .font(BovexaTheme.TypeStyle.caption.weight(.bold))
                .foregroundStyle(BovexaTheme.Colors.accent)
                .tracking(0.3)

            ForEach(viewModel.pending) { event in
                pendingCard(event)
            }
        }
    }

    /// Toewijzingen waarop nooit geantwoord is en waarvan de afspraak al voorbij is.
    /// Onder de actuele, zonder knoppen: accepteren of weigeren zegt niets meer over
    /// een dag die al geweest is. Weggooien ook niet — dan weet je nooit dat er iets
    /// langs is gekomen.
    private var expiredSection: some View {
        VStack(alignment: .leading, spacing: BovexaTheme.Space.sm) {
            Text("VERLOPEN")
                .font(BovexaTheme.TypeStyle.caption.weight(.bold))
                .foregroundStyle(BovexaTheme.Colors.muted)
                .tracking(0.3)

            ForEach(viewModel.expired) { event in
                GlassCard(emphasis: .quiet) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.title)
                            .font(BovexaTheme.TypeStyle.subheadline.weight(.semibold))
                            .foregroundStyle(BovexaTheme.Colors.inkSoft)
                        Text("\(EventHelpers.longDay(event.start)) · \(EventHelpers.rowTimeText(event)) · niet beantwoord")
                            .font(BovexaTheme.TypeStyle.footnote)
                            .foregroundStyle(BovexaTheme.Colors.muted)
                    }
                }
            }
        }
    }

    private func pendingCard(_ event: AgendaEvent) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BovexaTheme.Space.xs) {
                Text(event.title)
                    .font(BovexaTheme.TypeStyle.headline)
                    .foregroundStyle(BovexaTheme.Colors.ink)
                Text("\(EventHelpers.longDay(event.start)) · \(EventHelpers.rowTimeText(event))")
                    .font(BovexaTheme.TypeStyle.footnote)
                    .foregroundStyle(BovexaTheme.Colors.inkSoft)

                HStack(spacing: BovexaTheme.Space.sm) {
                    Button {
                        Task {
                            await viewModel.respond(event, status: "declined")
                            // Accepteren gaf wel terugkoppeling, weigeren niet (4h).
                            if !viewModel.respondFailedAlert { Haptics.selection() }
                        }
                    } label: {
                        Text("Weigeren").frame(maxWidth: .infinity, minHeight: 42)
                    }
                    .buttonStyle(.glassSecondaryBrand)
                    .disabled(viewModel.answeringId == event.id)

                    Button {
                        Task {
                            await viewModel.respond(event, status: "accepted")
                            if !viewModel.respondFailedAlert { Haptics.success() }
                        }
                    } label: {
                        if viewModel.answeringId == event.id {
                            ProgressView().tint(BovexaTheme.Colors.white).frame(maxWidth: .infinity, minHeight: 42)
                        } else {
                            Text("Accepteren").frame(maxWidth: .infinity, minHeight: 42)
                        }
                    }
                    .buttonStyle(.glassProminentBrand)
                    .disabled(viewModel.answeringId == event.id)
                }
                .padding(.top, BovexaTheme.Space.xs)
            }
        }
    }

    private var noticesSection: some View {
        VStack(alignment: .leading, spacing: BovexaTheme.Space.sm) {
            ForEach(viewModel.notices) { notice in
                GlassCard(emphasis: .quiet) {
                    VStack(alignment: .leading, spacing: BovexaTheme.Space.xs) {
                        if let title = notice.title, !title.isEmpty {
                            Text(title)
                                .font(BovexaTheme.TypeStyle.headline)
                                .foregroundStyle(BovexaTheme.Colors.ink)
                        }
                        Text(notice.body)
                            .font(BovexaTheme.TypeStyle.subheadline)
                            .foregroundStyle(BovexaTheme.Colors.inkSoft)
                        Text("\(notice.authorNaam.isEmpty ? "Team" : notice.authorNaam) · \(NoticeHelpers.relativeTime(notice.created))")
                            .font(BovexaTheme.TypeStyle.caption)
                            .foregroundStyle(BovexaTheme.Colors.muted)
                    }
                }
                // Long-press blijft, maar niemand vindt 'm: een contextMenu geeft
                // dezelfde actie mét preview en ontdekbaarheid (4h).
                .contextMenu {
                    if viewModel.canDelete(notice) {
                        Button("Verwijder", systemImage: "trash", role: .destructive) {
                            deleteTarget = notice
                        }
                    }
                }
                .onLongPressGesture(minimumDuration: 0.45) {
                    guard viewModel.canDelete(notice) else { return }
                    Haptics.selection()
                    deleteTarget = notice
                }
            }
        }
    }
}

#Preview {
    MeldingenView(userId: "u1", orgId: "org1", token: "tok")
}
