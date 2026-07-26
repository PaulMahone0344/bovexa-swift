import SwiftUI

struct AgendaView: View {
    @EnvironmentObject private var authStore: AuthStore
    @StateObject private var viewModel = AgendaViewModel()
    @StateObject private var speech = SpeechToTextService()
    @State private var selectedEvent: AgendaEvent?
    @State private var showSearch = false
    @State private var showLegende = false
    @State private var showPersoonKiezer = false
    @State private var showYearOverview = false
    @State private var pillText = ""
    @State private var plannerSeed: String?
    @State private var showPlanner = false
    @State private var speechAlertMessage: String?

    /// Anker om na een dag-tik naar het paneel onder de kalender te scrollen.
    private static let dayPanelAnchor = "day-panel"

    private var currentUser: AgendaUser? {
        if case .loggedIn(let user) = authStore.phase { return user }
        return nil
    }

    var body: some View {
        Group {
            if viewModel.viewKind == .dag, let userId = currentUser?.id {
                DayView(
                    viewModel: viewModel, currentUserId: userId,
                    onPlanAtHour: { hour, day in openPlanner(seed: PlannerSlotSeed.forHour(hour, on: day)) }
                )
            } else {
                monthOrListContent
            }
        }
        .safeAreaInset(edge: .bottom) {
            PlannerEntryPillView(
                text: $pillText, micAvailable: speech.available, listening: speech.listening,
                onMicTap: { Task { await speech.toggle() } },
                onSubmit: openPlannerFromPill, onOpenPlanner: openPlannerFromPill
            )
        }
        .task {
            await refresh()
        }
        .onAppear {
            Task { await refresh() }
        }
        // Het venster van de externe agenda loopt één maand vóór en ná de getoonde
        // maand; blader je verder, dan moet dat venster mee.
        .onChange(of: viewModel.displayedMonth) { _, _ in
            Task { await viewModel.refreshExternalForDisplayedMonth() }
        }
        .onChange(of: speech.transcript) { _, transcript in
            if !transcript.isEmpty { pillText = transcript }
        }
        .onChange(of: speech.error) { _, error in
            if let error { speechAlertMessage = error }
        }
        .alert("Spraak", isPresented: Binding(get: { speechAlertMessage != nil }, set: { if !$0 { speechAlertMessage = nil } })) {
            Button("Oké", role: .cancel) {}
        } message: {
            Text(speechAlertMessage ?? "")
        }
        .sheet(isPresented: $showPlanner) {
            if let userId = currentUser?.id {
                PlannerView(
                    userId: userId, token: authStore.token ?? "", org: currentUser?.defaultOrg,
                    memberColors: viewModel.memberColors, labelStore: viewModel.labelStore, seed: plannerSeed,
                    onConfirmed: { date in viewModel.openDayView(date) }
                )
            }
        }
    }

    private func openPlannerFromPill() {
        if speech.listening { speech.stop() }
        openPlanner(seed: pillText.trimmingCharacters(in: .whitespacesAndNewlines))
        pillText = ""
    }

    private func openPlanner(seed: String) {
        plannerSeed = seed.isEmpty ? nil : seed
        showPlanner = true
    }

    @ViewBuilder
    private var monthOrListContent: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                VStack(spacing: 0) {
                    if viewModel.viewKind == .lijst, let userId = currentUser?.id {
                        agendaHeader
                            .padding(.horizontal, BovexaTheme.Space.xl)
                        AgendaListView(viewModel: viewModel, currentUserId: userId, now: Date.init, selectedEvent: $selectedEvent)
                    } else {
                        ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: BovexaTheme.Space.lg) {
                                agendaHeader

                                MonthGridView(viewModel: viewModel, onYearTap: { showYearOverview = true })

                                // Dagoverzicht onder de kalender in plaats van de
                                // sheet die er tot 26 juli overheen schoof: de
                                // blokjes in een maandcel zijn te klein om de dag
                                // uit te lezen, en de ruimte hieronder stond leeg.
                                if let target = viewModel.daySheetTarget, let userId = currentUser?.id {
                                    DayPanelView(
                                        day: target.day,
                                        events: viewModel.eventsOnDay(target.day),
                                        currentUserId: userId,
                                        memberColors: viewModel.memberColors,
                                        labelStore: viewModel.labelStore,
                                        onOpenDay: { viewModel.openDayView(target.day) },
                                        onSelectEvent: { event in selectedEvent = event },
                                        onPlanAppointment: {
                                            openPlanner(seed: PlannerSlotSeed.forDay(target.day))
                                        }
                                    )
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                    .id(Self.dayPanelAnchor)
                                }
                            }
                            .padding(.horizontal, BovexaTheme.Space.xl)
                            .padding(.top, BovexaTheme.Space.xs)
                            // De laatste week liep tegen de plan-knop en de
                            // tabbalk aan, waardoor de kalender eronder leek
                            // door te lopen.
                            .padding(.bottom, BovexaTheme.Space.tabBarClearance)
                            .animation(.snappy(duration: 0.25), value: viewModel.daySheetTarget)
                        }
                        // Het paneel staat onder een volle maandkalender en viel
                        // dus buiten beeld: je tikte een dag aan en zag niets
                        // gebeuren.
                        .onChange(of: viewModel.daySheetTarget) { _, target in
                            guard target != nil else { return }
                            withAnimation(.snappy(duration: 0.3)) {
                                proxy.scrollTo(Self.dayPanelAnchor, anchor: .bottom)
                            }
                        }
                        }
                    }
                }
                .safeAreaInset(edge: .top, spacing: 0) { persoonFilterChip }
            }
            // Eigen kop in plaats van de grote systeemtitel: de vier iconen
            // zweefden als losse pil boven "Agenda" zonder zichtbare relatie met
            // de titel, en de titel duwde de maandregel ver naar beneden.
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $selectedEvent) { event in
                if let userId = currentUser?.id {
                    EventDetailView(
                        event: event, currentUserId: userId, currentUserOrgId: currentUser?.defaultOrg,
                        token: authStore.token ?? "", memberColors: viewModel.memberColors, labelStore: viewModel.labelStore
                    )
                }
            }
            .sheet(isPresented: $showSearch) {
                if let userId = currentUser?.id {
                    SearchView(
                        userId: userId, orgId: currentUser?.defaultOrg, token: authStore.token ?? "",
                        currentUserOrgId: currentUser?.defaultOrg, memberColors: viewModel.memberColors,
                        labelStore: viewModel.labelStore
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
        HStack(alignment: .center, spacing: BovexaTheme.Space.xs) {
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
                    .frame(width: 34, height: 34)
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
                .frame(width: 34, height: 34)
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
                }
                .accessibilityLabel("Alleen mijn eigen agenda tonen")
            }
            .padding(.horizontal, BovexaTheme.Space.md)
            .padding(.vertical, BovexaTheme.Space.xs)
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
