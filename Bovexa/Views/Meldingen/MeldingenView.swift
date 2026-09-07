import SwiftUI

/// Meldingen: toewijzingen die op jouw akkoord wachten + bedrijfsmededelingen
/// (valkuil D). Geport uit meldingen.tsx. Plus-knop alleen admin/manager (valkuil E),
/// lang indrukken op je eigen mededeling verwijdert 'm.
struct MeldingenView: View {
    @EnvironmentObject private var badgeStore: BadgeStore
    @FocusState private var composeFocused: Bool
    @StateObject private var viewModel: MeldingenViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var deleteTarget: Notice?
    /// Notitie per aanvraag, zolang de beheerder nog niet heeft geantwoord.
    @State private var notities: [String: String] = [:]

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

                        if !viewModel.eigenAanvragen.isEmpty {
                            aanvraagSection
                        }

                        if !viewModel.expired.isEmpty {
                            expiredSection
                        }

                        if viewModel.toontTeamActiviteit, !viewModel.teamActiviteit.isEmpty {
                            teamActiviteitSection
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
                SheetCloseButton { dismiss() }
            }
        }
        .task { await viewModel.load() }
        // De sheet markeert de mededelingen als gezien en handelt toewijzingen af;
        // zonder dit bleef het cijfer op de tab staan tot de volgende load (6b).
        .onChange(of: viewModel.pending.count, initial: true) { _, count in
            badgeStore.setPendingAssignments(count)
        }
        .onChange(of: viewModel.loaded) { _, loaded in
            if loaded { badgeStore.clearNotices() }
        }
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

                // Ruimte voor een woordje uitleg bij je antwoord; die komt bij de
                // aanvrager onder de uitslag te staan.
                TextField("Notitie (optioneel)", text: Binding(
                    get: { notities[event.id] ?? "" },
                    set: { notities[event.id] = $0 }
                ))
                .textFieldStyle(.plain)
                .padding(BovexaTheme.Space.sm)
                .background(BovexaTheme.Colors.glassSoft)
                .clipShape(RoundedRectangle(cornerRadius: BovexaTheme.Radius.sm, style: .continuous))
                .padding(.top, BovexaTheme.Space.xs)

                HStack(spacing: BovexaTheme.Space.sm) {
                    Button {
                        Task {
                            await viewModel.respond(event, status: "declined", notitie: notities[event.id] ?? "")
                            // Accepteren gaf wel terugkoppeling, weigeren niet (4h).
                            if !viewModel.respondFailedAlert { Haptics.selection() }
                        }
                    } label: {
                        Text("Weigeren").frame(maxWidth: .infinity, minHeight: 42)
                    }
                    .buttonStyle(.glassSecondaryDanger)
                    .disabled(viewModel.answeringId == event.id)

                    Button {
                        Task {
                            await viewModel.respond(event, status: "accepted", notitie: notities[event.id] ?? "")
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

    /// Wat jij hebt doorgegeven en wat de beheerder ermee deed.
    /// Wat medewerkers zelf in de agenda hebben gezet. Geen knoppen: dit is een
    /// overzicht, geen verzoek — tikken opent de afspraak, verder hoeft er niets.
    private var teamActiviteitSection: some View {
        VStack(alignment: .leading, spacing: BovexaTheme.Space.sm) {
            Text("INGEVOERD DOOR HET TEAM")
                .font(BovexaTheme.TypeStyle.caption.weight(.bold))
                .foregroundStyle(BovexaTheme.Colors.accent)
                .tracking(0.3)

            GlassCard(padding: BovexaTheme.Space.xs, emphasis: .quiet) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(viewModel.teamActiviteit.enumerated()), id: \.element.id) { index, event in
                        if index > 0 {
                            Divider().overlay(BovexaTheme.Colors.edge)
                        }
                        teamActiviteitRij(event)
                    }
                }
            }
        }
    }

    private func teamActiviteitRij(_ event: AgendaEvent) -> some View {
        HStack(spacing: BovexaTheme.Space.sm) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(event.category.map { BovexaTheme.categoryColor(for: $0) } ?? BovexaTheme.Colors.blue)
                .frame(width: 4, height: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title.isEmpty ? "Afspraak" : event.title)
                    .font(BovexaTheme.TypeStyle.subheadline.weight(.semibold))
                    .foregroundStyle(BovexaTheme.Colors.ink)
                    .lineLimit(1)
                Text(TeamActiviteit.omschrijving(event, naam: viewModel.naam(voor: event.owner)))
                    .font(BovexaTheme.TypeStyle.footnote)
                    .foregroundStyle(BovexaTheme.Colors.inkSoft)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, BovexaTheme.Space.xs)
        .padding(.horizontal, BovexaTheme.Space.sm)
    }

    private var aanvraagSection: some View {
        VStack(alignment: .leading, spacing: BovexaTheme.Space.sm) {
            Text("JE EIGEN AANVRAGEN")
                .font(BovexaTheme.TypeStyle.caption.weight(.bold))
                .foregroundStyle(BovexaTheme.Colors.accent)
                .tracking(0.3)

            ForEach(viewModel.eigenAanvragen) { event in
                aanvraagKaart(event)
            }
        }
    }

    private func aanvraagKaart(_ event: AgendaEvent) -> some View {
        let stand = AanvraagStatus.stand(event)
        return GlassCard(emphasis: .quiet) {
            VStack(alignment: .leading, spacing: BovexaTheme.Space.xs) {
                HStack(alignment: .firstTextBaseline) {
                    Text(event.title)
                        .font(BovexaTheme.TypeStyle.headline)
                        .foregroundStyle(BovexaTheme.Colors.ink)
                    Spacer(minLength: BovexaTheme.Space.sm)
                    Text(stand.label)
                        .font(BovexaTheme.TypeStyle.caption.weight(.bold))
                        .foregroundStyle(standKleur(stand))
                        .padding(.horizontal, BovexaTheme.Space.sm)
                        .padding(.vertical, 4)
                        .background(standKleur(stand).opacity(0.15))
                        .clipShape(Capsule())
                }

                Text("\(EventHelpers.longDay(event.start)) · \(EventHelpers.rowTimeText(event))")
                    .font(BovexaTheme.TypeStyle.footnote)
                    .foregroundStyle(BovexaTheme.Colors.inkSoft)

                // De beheerder kan er een reden bij zetten; die staat sinds punt 19
                // in `reactie`. `notes` blijft jouw eigen opmerking bij de aanvraag
                // en hoort hier dus niet als antwoord getoond te worden.
                if let reactie = event.reactie, !reactie.isEmpty {
                    Text("Reactie beheerder: \(reactie)")
                        .font(BovexaTheme.TypeStyle.footnote)
                        .foregroundStyle(BovexaTheme.Colors.muted)
                        .padding(.top, 2)
                }
            }
        }
    }

    private func standKleur(_ stand: AanvraagStand) -> Color {
        switch stand {
        case .wacht: return BovexaTheme.Colors.muted
        case .goedgekeurd: return BovexaTheme.Colors.categoryGreen
        case .afgewezen: return BovexaTheme.Colors.danger
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
