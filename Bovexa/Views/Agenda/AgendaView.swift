import SwiftUI

struct AgendaView: View {
    @EnvironmentObject private var authStore: AuthStore
    @StateObject private var viewModel = AgendaViewModel()
    @State private var selectedEvent: AgendaEvent?
    @State private var showSearch = false
    @State private var showLegende = false
    @State private var showPersoonKiezer = false
    @State private var showYearOverview = false
    @State private var plannerSeed: String?
    @State private var showPlanner = false
    @State private var nieuweAfspraak: NieuweAfspraakTarget?
    @State private var planKeuze: PlanKeuzeTarget?
    /// Wat er ná het sluiten van de keuze-sheet moet gebeuren. Twee sheets die
    /// elkaar in dezelfde tik afwisselen laat SwiftUI vallen; daarom pas openen als
    /// de eerste echt weg is.
    @State private var naKeuze: NaKeuze?

    /// Onderkant van het maandraster en de schermhoogte, allebei in schermpunten.
    /// Hieruit volgt hoe hoog de dagbalk mag worden: precies de ruimte onder de
    /// kalender, zodat de dagen zichtbaar blijven in plaats van half afgedekt.
    @State private var kalenderOnderkant: CGFloat = 0
    @State private var schermHoogte: CGFloat = 0

    /// Nooit lager dan dit: onder een volle maand blijft anders niet eens de
    /// dagkop met de plan-knop over. Verder omhoog kan altijd met de greep.
    private static let minimaleDagbalk: CGFloat = 260

    /// De dagbalk vult de ruimte ónder de kalender, maar nooit meer dan de helft
    /// van het scherm: bij een dag met veel blokken schoof hij anders over de
    /// kalender heen. Wat er niet in past scrollt gewoon binnen de balk.
    @State private var dagbalkStand: PresentationDetent = .large

    private var dagbalkHoogte: CGFloat {
        guard schermHoogte > 0, kalenderOnderkant > 0 else { return Self.minimaleDagbalk }
        let ruimteOnderKalender = schermHoogte - kalenderOnderkant
        return min(max(Self.minimaleDagbalk, ruimteOnderKalender), schermHoogte * 0.55)
    }

    /// `.sheet(item:)` in plaats van een losse bool: de voorzet en het openen komen
    /// dan als één waarde binnen, en niet als twee @State-wijzigingen waarvan de
    /// tweede te laat kan zijn.
    private struct NieuweAfspraakTarget: Identifiable {
        let id = UUID()
        let seed: NieuweAfspraakSeed
    }

    /// Draagt de voorzet mee de keuze-sheet in: welke dag (of welk uur) de
    /// gebruiker aanwees blijft zo behouden, welke route hij daarna ook kiest.
    private struct PlanKeuzeTarget: Identifiable {
        let id = UUID()
        let seed: NieuweAfspraakSeed
    }

    private enum NaKeuze {
        case handmatig(NieuweAfspraakSeed)
        case ai(NieuweAfspraakSeed)
    }

    private var currentUser: AgendaUser? {
        if case .loggedIn(let user) = authStore.phase { return user }
        return nil
    }

    var body: some View {
        Group {
            if viewModel.viewKind == .dag, let userId = currentUser?.id {
                DayView(
                    viewModel: viewModel, currentUserId: userId,
                    // Long-press op een leeg uur: ook hier eerst de vraag
                    // handmatig of AI. Dag én uur gaan als voorzet mee, dus welke
                    // route je ook kiest, je begint op het aangewezen tijdstip.
                    onPlanAtHour: { hour, day in openPlanKeuze(seed: .forHour(hour, on: day)) }
                )
            } else {
                monthOrListContent
            }
        }
        .safeAreaInset(edge: .bottom) {
            NieuweAfspraakKnop { openPlanKeuze(seed: .empty) }
        }
        // Eén laadpad (zie VandaagView): `.task` herstart al bij elke terugkeer
        // naar deze tab.
        .task {
            await refresh()
        }
        .onChange(of: authStore.foregroundTick) { _, _ in
            Task { await refresh() }
        }
        // Het venster van de externe agenda loopt één maand vóór en ná de getoonde
        // maand; blader je verder, dan moet dat venster mee.
        .onChange(of: viewModel.displayedMonth) { _, _ in
            Task { await viewModel.refreshExternalForDisplayedMonth() }
        }
        // Terug naar een popup bij het kiezen van een dag (verzoek opdrachtgever
        // 26 juli): het paneel onder de kalender vroeg om scrollen en duwde de
        // maand omhoog. De inhoud is wél de nieuwe: met dagtotaal en plan-knop.
        .sheet(item: $viewModel.daySheetTarget) { target in
            if let userId = currentUser?.id {
                DaySheetView(
                    day: target.day,
                    events: viewModel.eventsOnDay(target.day),
                    currentUserId: userId,
                    memberColors: viewModel.memberColors,
                    labelStore: viewModel.labelStore,
                    onOpenDay: { viewModel.openDayView(target.day) },
                    onSelectEvent: { event in
                        viewModel.closeDaySheet()
                        selectedEvent = event
                    },
                    onPlanAppointment: {
                        // Valkuil C: de dagsheet moet eerst dicht in dezelfde tick,
                        // anders blijft hij onder de keuzesheet hangen.
                        viewModel.closeDaySheet()
                        openPlanKeuze(seed: .forDay(target.day))
                    },
                    hoogte: dagbalkHoogte,
                    stand: $dagbalkStand
                )
                .onAppear {
                    // De stand hoort bij deze sheet, niet bij de vorige: zonder dit
                    // opende de volgende dag nog in de stand waar je hem liet staan.
                    dagbalkStand = viewModel.dagbalkUitgeklapt ? .large : .height(dagbalkHoogte)
                }
            }
        }
        .sheet(isPresented: $showPlanner) {
            if let userId = currentUser?.id {
                PlannerView(
                    userId: userId, token: authStore.token ?? "", org: currentUser?.defaultOrg,
                    memberColors: viewModel.memberColors, labelStore: viewModel.labelStore, seed: plannerSeed,
                    // Opnieuw laden hoort hier: de planner maakt de afspraak aan op de
                    // server, en de Agenda laadt zichzelf niet als een sheet sluit.
                    // Zonder dit stond de nieuwe afspraak er pas na een herstart.
                    onConfirmed: { date in
                        viewModel.openDayView(date)
                        Task { await viewModel.reload() }
                    }
                )
            }
        }
        .sheet(item: $planKeuze, onDismiss: voerNaKeuzeUit) { target in
            PlanKeuzeSheet(
                onHandmatig: {
                    naKeuze = .handmatig(target.seed)
                    planKeuze = nil
                },
                onAI: {
                    naKeuze = .ai(target.seed)
                    planKeuze = nil
                }
            )
        }
        .sheet(item: $nieuweAfspraak) { target in
            if let userId = currentUser?.id {
                NieuweAfspraakView(
                    seed: target.seed, userId: userId, token: authStore.token ?? "",
                    org: currentUser?.defaultOrg, memberColors: viewModel.memberColors,
                    labelStore: viewModel.labelStore,
                    defaultDurationMin: viewModel.memberColors.orgDefaultDurationMin ?? EventEditorViewModel.fallbackDurationMin,
                    // Zelfde pad als de planner: naar die dag springen én herladen.
                    onConfirmed: { date in
                        viewModel.openDayView(date)
                        Task { await viewModel.reload() }
                    }
                )
            }
        }
    }

    /// De plan-pill: mét tekst ga je meteen naar de planner — die keuze is dan al
    /// gemaakt en een keuzesheet ertussen zou een extra tik zijn. Zonder tekst opent
    /// de keuzesheet, want dan is nog niet gezegd of het met AI of handmatig moet.
    /// Draait de gemaakte keuze uit, nadat de keuze-sheet is gesloten.
    private func voerNaKeuzeUit() {
        guard let keuze = naKeuze else { return }
        naKeuze = nil
        switch keuze {
        case .handmatig(let seed):
            openNieuweAfspraak(seed: seed)
        case .ai(let seed):
            // Geen aangewezen dag ⇒ nil ⇒ de planner opent met zijn startkaart,
            // precies zoals vóór deze wijziging.
            openPlanner(seed: seed.plannerSeed() ?? "")
        }
    }

    private func openPlanKeuze(seed: NieuweAfspraakSeed) {
        planKeuze = PlanKeuzeTarget(seed: seed)
    }

    private func openPlanner(seed: String) {
        plannerSeed = seed.isEmpty ? nil : seed
        showPlanner = true
    }

    private func openNieuweAfspraak(seed: NieuweAfspraakSeed) {
        nieuweAfspraak = NieuweAfspraakTarget(seed: seed)
    }

    @ViewBuilder
    private var monthOrListContent: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                VStack(spacing: 0) {
                    if viewModel.loadFailed {
                        LoadFailedNote(surface: .background)
                            .padding(.horizontal, BovexaTheme.Space.xl)
                            .padding(.bottom, BovexaTheme.Space.xs)
                    }
                    if viewModel.viewKind == .lijst, let userId = currentUser?.id {
                        agendaHeader
                            .padding(.horizontal, BovexaTheme.Space.xl)
                        AgendaListView(viewModel: viewModel, currentUserId: userId, now: Date.init, selectedEvent: $selectedEvent)
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: BovexaTheme.Space.lg) {
                                agendaHeader

                                MonthGridView(viewModel: viewModel, onYearTap: { showYearOverview = true })
                                    // Waar het maandraster eindigt, mag de dagbalk
                                    // beginnen. Zonder deze meting stond hij op een
                                    // vaste halve hoogte en viel hij over de dagen.
                                    .onGeometryChange(for: CGFloat.self) { proxy in
                                        proxy.frame(in: .global).maxY
                                    } action: { kalenderOnderkant = $0 }

                            }
                            .padding(.horizontal, BovexaTheme.Space.xl)
                            .padding(.top, BovexaTheme.Space.xs)
                            // De laatste week liep tegen de plan-knop en de
                            // tabbalk aan, waardoor de kalender eronder leek
                            // door te lopen.
                            .padding(.bottom, BovexaTheme.Space.tabBarClearance)
                            .animation(.snappy(duration: 0.25), value: viewModel.daySheetTarget)
                        }
                    }
                }
                .safeAreaInset(edge: .top, spacing: 0) { persoonFilterChip }
                // Schermhoogte als maatstaf voor de dagbalk: die mag precies de
                // ruimte onder het maandraster vullen.
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.frame(in: .global).maxY
                } action: { schermHoogte = $0 }
            }
            // Eigen kop in plaats van de grote systeemtitel: de vier iconen
            // zweefden als losse pil boven "Agenda" zonder zichtbare relatie met
            // de titel, en de titel duwde de maandregel ver naar beneden.
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $selectedEvent) { event in
                if let userId = currentUser?.id {
                    EventDetailView(
                        event: event, currentUserId: userId, currentUserOrgId: currentUser?.defaultOrg,
                        token: authStore.token ?? "", memberColors: viewModel.memberColors, labelStore: viewModel.labelStore,
                        onChanged: { Task { await viewModel.reload() } },
                        onDeleted: { recordId in
                            viewModel.removeLocally(recordId: recordId)
                            Task { await viewModel.reload() }
                        }
                    )
                }
            }
            .sheet(isPresented: $showSearch, onDismiss: { Task { await viewModel.reload() } }) {
                if let userId = currentUser?.id {
                    SearchView(
                        userId: userId, orgId: currentUser?.defaultOrg, token: authStore.token ?? "",
                        currentUserOrgId: currentUser?.defaultOrg, memberColors: viewModel.memberColors,
                        labelStore: viewModel.labelStore,
                        onAgendaChanged: { Task { await viewModel.reload() } }
                    )
                }
            }
            .sheet(isPresented: $showPersoonKiezer) {
                if let userId = currentUser?.id {
                    AgendaPersoonKiezerView(
                        memberColors: viewModel.memberColors, currentUserId: userId,
                        selected: viewModel.selectedPeople,
                        onToggle: { viewModel.togglePerson($0) },
                        onSelectEveryone: { viewModel.showEveryone() },
                        onSelectOnlyMe: { viewModel.showOnlyOwnAgenda() }
                    )
                }
            }
            .sheet(isPresented: $showLegende) {
                if let userId = currentUser?.id, let org = currentUser?.defaultOrg {
                    LegendeView(userId: userId, org: org, token: authStore.token ?? "", labelStore: viewModel.labelStore)
                }
            }
            .sheet(isPresented: $showYearOverview) {
                if let userId = currentUser?.id {
                    YearOverviewView(userId: userId, orgId: currentUser?.defaultOrg, token: authStore.token ?? "") { date in
                        showYearOverview = false
                        viewModel.openDayView(date)
                    }
                }
            }
        }
    }

    /// Kop van de Agenda: de titel met de vier knoppen ernaast, in plaats van de
    /// grote systeemtitel met een zwevende icoonpil erboven. Die pil stond los van
    /// alles en de systeemtitel duwde de maandregel ver naar beneden.
    private var agendaHeader: some View {
        HStack(alignment: .center, spacing: 0) {
            Text("Agenda")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(BovexaTheme.Colors.ink)

            Spacer(minLength: BovexaTheme.Space.sm)

            headerButton("magnifyingglass", label: "Zoeken") { showSearch = true }

            if viewModel.canSeeOthersAgenda {
                headerButton("person.2", label: "Wie zie je") { showPersoonKiezer = true }
            }

            headerButton("tag", label: "Legenda") { showLegende = true }

            Menu {
                ForEach(AgendaViewKind.allCases.filter { $0 != .dag }, id: \.self) { kind in
                    Button {
                        withAnimation(.snappy) { viewModel.setViewKind(kind) }
                    } label: {
                        if viewModel.viewKind == kind {
                            Label(kind.label, systemImage: "checkmark")
                        } else {
                            Text(kind.label)
                        }
                    }
                }
            } label: {
                Image(systemName: "square.3.layers.3d")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(BovexaTheme.Colors.accent)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Weergave")
        }
    }

    private func headerButton(_ systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(BovexaTheme.Colors.accent)
                // 44 sinds M11 (was 34); het icoon blijft 16pt. De HStack-spacing ging
                // daarom naar 0 — op 375pt past "Agenda" + vier knoppen precies.
                .frame(width: 44, height: 44)
                // Glas telt niet mee voor hit-testing; zonder dit is alleen het
                // icoontje zelf raakbaar.
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    /// Zichtbaar zodra er collega's bij staan. Zonder dat teken is een vol raster
    /// niet te onderscheiden van je eigen drukke dag: je ziet twintig blokken en
    /// weet niet van wie ze zijn.
    @ViewBuilder
    private var persoonFilterChip: some View {
        let extra = viewModel.extraPeople
        if let label = AgendaFilterChipText.text(
            extraNames: extra.compactMap { viewModel.memberColors.firstName(for: $0) }
        ) {
            HStack(spacing: BovexaTheme.Space.xs) {
                ForEach(extra.sorted().prefix(3), id: \.self) { userId in
                    Circle()
                        .fill(viewModel.memberColors.color(for: userId))
                        .frame(width: 10, height: 10)
                }
                Text(label)
                    .font(BovexaTheme.TypeStyle.footnote.weight(.semibold))
                    .foregroundStyle(BovexaTheme.Colors.ink)
                Button {
                    Haptics.selection()
                    viewModel.showOnlyOwnAgenda()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(BovexaTheme.Colors.muted)
                        .minTapTarget()
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Alleen mijn eigen agenda tonen")
            }
            .padding(.leading, BovexaTheme.Space.md)
            // Het kruisje draagt zijn eigen 44pt; extra rechterpadding zou de chip
            // onnodig breed maken.
            .padding(.trailing, BovexaTheme.Space.xs)
            .background(BovexaTheme.Colors.floatingSurface)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(BovexaTheme.Colors.edge, lineWidth: 1))
            .padding(.horizontal, BovexaTheme.Space.xl)
            .padding(.bottom, BovexaTheme.Space.xs)
            // Links uitlijnen zoals de rest van het scherm; zonder dit gaat de chip
            // in het midden hangen omdat hij naar zijn inhoud krimpt.
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func refresh() async {
        guard let user = currentUser else { return }
        await viewModel.load(userId: user.id, orgId: user.defaultOrg, token: authStore.token ?? "")
    }
}

#Preview {
    AgendaView().environmentObject(AuthStore())
}
