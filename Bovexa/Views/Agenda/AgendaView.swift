import SwiftUI

struct AgendaView: View {
    @EnvironmentObject private var authStore: AuthStore
    @StateObject private var viewModel = AgendaViewModel()
    @State private var selectedEvent: AgendaEvent?
    @State private var showSearch = false
    @State private var showYearOverview = false

    private var currentUser: AgendaUser? {
        if case .loggedIn(let user) = authStore.phase { return user }
        return nil
    }

    var body: some View {
        Group {
            if viewModel.viewKind == .dag, let userId = currentUser?.id {
                DayView(viewModel: viewModel, currentUserId: userId)
            } else {
                monthOrListContent
            }
        }
        .task {
            await refresh()
        }
        .onAppear {
            Task { await refresh() }
        }
        .sheet(item: $viewModel.daySheetTarget) { target in
            if let userId = currentUser?.id {
                DaySheetView(
                    day: target.day,
                    events: viewModel.eventsOnDay(target.day),
                    currentUserId: userId,
                    memberColors: viewModel.memberColors,
                    onOpenDay: { viewModel.openDayView(target.day) },
                    onSelectEvent: { event in
                        viewModel.closeDaySheet()
                        selectedEvent = event
                    }
                )
            }
        }
    }

    @ViewBuilder
    private var monthOrListContent: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                VStack(spacing: BovexaTheme.Space.lg) {
                    header

                    if viewModel.viewKind == .lijst, let userId = currentUser?.id {
                        AgendaListView(viewModel: viewModel, currentUserId: userId, now: Date.init, selectedEvent: $selectedEvent)
                    } else {
                        ScrollView {
                            MonthGridView(viewModel: viewModel, onYearTap: { showYearOverview = true })
                                .padding(BovexaTheme.Space.xl)
                        }
                    }
                }
            }
            .navigationDestination(item: $selectedEvent) { event in
                if let userId = currentUser?.id {
                    EventDetailView(
                        event: event, currentUserId: userId, currentUserOrgId: currentUser?.defaultOrg,
                        token: authStore.token ?? "", memberColors: viewModel.memberColors
                    )
                }
            }
            .sheet(isPresented: $showSearch) {
                if let userId = currentUser?.id {
                    SearchView(
                        userId: userId, orgId: currentUser?.defaultOrg, token: authStore.token ?? "",
                        currentUserOrgId: currentUser?.defaultOrg, memberColors: viewModel.memberColors
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

    private var header: some View {
        HStack {
            Text("Agenda")
                .font(.system(size: BovexaTheme.TypeScale.h2, weight: .bold))
                .foregroundStyle(BovexaTheme.Colors.ink)

            Spacer()

            Button {
                showSearch = true
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(BovexaTheme.Colors.ink)
            }
            .padding(.trailing, BovexaTheme.Space.md)

            Menu {
                ForEach(AgendaViewKind.allCases.filter { $0 != .dag }, id: \.self) { kind in
                    Button {
                        viewModel.setViewKind(kind)
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
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(BovexaTheme.Colors.ink)
            }
        }
        .padding(.horizontal, BovexaTheme.Space.xl)
        .padding(.top, BovexaTheme.Space.lg)
    }

    private func refresh() async {
        guard let user = currentUser else { return }
        await viewModel.load(userId: user.id, orgId: user.defaultOrg, token: authStore.token ?? "")
    }
}

#Preview {
    AgendaView().environmentObject(AuthStore())
}
