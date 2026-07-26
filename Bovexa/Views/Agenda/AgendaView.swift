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
                        viewModel.closeDaySheet()
                        openPlanner(seed: PlannerSlotSeed.forDay(target.day))
                    }
                )
            }
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
                        AgendaListView(viewModel: viewModel, currentUserId: userId, now: Date.init, selectedEvent: $selectedEvent)
                    } else {
                        ScrollView {
                            MonthGridView(viewModel: viewModel, onYearTap: { showYearOverview = true })
                                .padding(.horizontal, BovexaTheme.Space.xl)
                                // Boven de maandregel stond 24pt bovenop de ruimte
                                // die de grote titel al meebrengt; dat was een gat.
                                .padding(.top, BovexaTheme.Space.xs)
                                // De laatste week liep tegen de plan-knop en de
                                // tabbalk aan, waardoor de kalender eronder leek
                                // door te lopen.
                                .padding(.bottom, BovexaTheme.Space.tabBarClearance)
                        }
                    }
                }
                // Via safeAreaInset en niet als eerste kind van de VStack: daar
                // liet de grote titel "Agenda" zich niet meer tekenen zodra de chip
                // verscheen. Zo blijft de titel staan en zakt de inhoud eronder.
                .safeAreaInset(edge: .top, spacing: 0) { persoonFilterChip }
            }
            .navigationTitle("Agenda")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                // "Beschikbaarheid doorgeven" stond hier ook, maar staat al als rij
                // op Profiel. Vijf iconen naast elkaar werd te vol; deze hoort bij
                // je eigen gegevens, niet bij het bekijken van de agenda.
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSearch = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .accessibilityLabel("Zoeken")
                }
                if viewModel.canSeeOthersAgenda {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showPersoonKiezer = true
                        } label: {
                            Image(systemName: "person.2")
                        }
                        .accessibilityLabel("Agenda van een collega")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showLegende = true
                    } label: {
                        Image(systemName: "tag")
                    }
                    .accessibilityLabel("Legenda")
                }
                ToolbarItem(placement: .topBarTrailing) {
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
                    }
                }
            }
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
