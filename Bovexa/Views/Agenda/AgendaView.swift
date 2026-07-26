import SwiftUI

struct AgendaView: View {
    @EnvironmentObject private var authStore: AuthStore
    @StateObject private var viewModel = AgendaViewModel()
    @StateObject private var speech = SpeechToTextService()
    @State private var selectedEvent: AgendaEvent?
    @State private var showSearch = false
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
                        openPlanner(seed: PlannerSlotSeed.forHour(7, on: target.day))
                    }
                )
            }
        }
        .sheet(isPresented: $showPlanner) {
            if let userId = currentUser?.id {
                PlannerView(
                    userId: userId, token: authStore.token ?? "", org: currentUser?.defaultOrg,
                    memberColors: viewModel.memberColors, seed: plannerSeed,
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

    private func categoryLabel(_ category: BovexaTheme.Category) -> String {
        switch category {
        case .work: return "Werk"
        case .focus: return "Focus"
        case .social: return "Sociaal"
        case .body: return "Lichaam"
        case .afwezig: return "Afwezig"
        }
    }

    @ViewBuilder
    private var monthOrListContent: some View {
        NavigationStack {
            ZStack {
                AppBackground()

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
            .navigationTitle("Agenda")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSearch = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
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

                        // De kleuren zijn nergens uitgelegd; een nieuwe gebruiker
                        // ziet turquoise/geel/paars zonder te weten wat ze
                        // betekenen. Het lagen-menu is de plek waar je toch al
                        // kijkt als je de weergave wilt begrijpen.
                        Section("Kleuren") {
                            ForEach(BovexaTheme.Category.allCases, id: \.self) { category in
                                Label(categoryLabel(category), systemImage: "circle.fill")
                                    .foregroundStyle(BovexaTheme.categoryColor(for: category))
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

    private func refresh() async {
        guard let user = currentUser else { return }
        await viewModel.load(userId: user.id, orgId: user.defaultOrg, token: authStore.token ?? "")
    }
}

#Preview {
    AgendaView().environmentObject(AuthStore())
}
