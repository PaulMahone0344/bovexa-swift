import SwiftUI

struct VandaagView: View {
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var router: TabRouter
    @StateObject private var viewModel = VandaagViewModel()
    @State private var selectedEvent: AgendaEvent?

    private var currentUser: AgendaUser? {
        if case .loggedIn(let user) = authStore.phase { return user }
        return nil
    }

    /// "zaterdag 25 juli" — de grote titel zegt alleen "Vandaag"; welke dag dat
    /// is stond nergens.
    private var todayLine: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nl_NL")
        formatter.dateFormat = "EEEE d MMMM"
        return formatter.string(from: Date())
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: BovexaTheme.Space.lg) {
                        header

                        if let userId = currentUser?.id {
                            NextUpCard(
                                event: viewModel.nextEvent,
                                hadEventsToday: !viewModel.todayEvents.isEmpty,
                                currentUserId: userId,
                                memberColors: viewModel.memberColors,
                                onOpen: { selectedEvent = $0 }
                            )
                        }

                        statsRow

                        timeline

                        // "Deze week" stond hier tot 26 juli: zeven staafjes met
                        // de drukte per dag. Eruit op verzoek van de opdrachtgever
                        // — het herhaalde wat de agenda zelf al laat zien.
                        // WeekBusyCard blijft in de repo staan voor het geval het
                        // terugkomt. Hiervoor in de plaats: de dagtaken, de enige
                        // informatie op dit scherm die niet uit de agenda komt.
                        OpenTasksCard(tasks: viewModel.openTasks) {
                            router.open(.dagtaken)
                        }
                    }
                    .padding(BovexaTheme.Space.xl)
                    // De zwevende tabbalk ligt óver de content. Zonder deze
                    // marge staat de laatste kaart er half achter zodra je
                    // helemaal naar beneden scrolt.
                    .padding(.bottom, BovexaTheme.Space.tabBarClearance)
                    .animation(.smooth(duration: 0.3), value: viewModel.nextEvent?.id)
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
            // Geen systeemtitel: die staat vast links bovenin en laat het logo
            // niet boven zich toe. De kop is nu een eigen blok, zoals de mockup.
            .toolbar(.hidden, for: .navigationBar)
        }
        .task {
            await refresh()
        }
        .onAppear {
            // Dagtaken staan lokaal en kunnen op de andere tab veranderd zijn;
            // dit is goedkoop (UserDefaults) en hoeft niet op het netwerk te
            // wachten, dus los van refresh().
            viewModel.reloadOpenTasks()
            Task { await refresh() }
        }
    }

    /// Kop zoals de mockup: logo rechtsboven, daaronder de grote titel met de
    /// datum er strak onder, en rechts de zon achter de berg. Vervangt de grote
    /// iOS-titel — die stond altijd links bovenin en duwde het logo weg.
    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                // Het bedrijfslogo is een upload van het bedrijf zelf. Een kader
                // eromheen laat het als advertentie lezen; het blijft dus een vrij
                // staand merkteken, alleen groter dan voorheen.
                if let logoURL = viewModel.orgLogoURL {
                    AsyncImage(url: logoURL) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        Color.clear
                    }
                    // Kleiner dan 118×24: daar hield het logo de titel eronder in
                    // evenwicht in plaats van eronder te blijven.
                    .frame(maxWidth: 96, maxHeight: 20)
                }
            }

            ZStack(alignment: .topTrailing) {
                VandaagHeaderArt()
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .offset(y: 8)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Vandaag")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(BovexaTheme.Colors.ink)

                    // `muted` staat hier direct op de ondergrond, niet op glas:
                    // daar is die ondergrond te verzadigd voor. `inkSoft` houdt
                    // het rustig én leesbaar.
                    Text(todayLine)
                        .font(BovexaTheme.TypeStyle.subheadline)
                        .foregroundStyle(BovexaTheme.Colors.inkSoft)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 6)
            }
        }
        .padding(.horizontal, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Vandaag, \(todayLine)")
    }

    /// Twee cijfers naast elkaar als rustige pillen: informatie die je wel wilt
    /// zien, maar die de hero-kaart niet mag beconcurreren.
    private var statsRow: some View {
        // .top plus gelijke hoogtes: de tegels stonden los van elkaar uitgelijnd
        // omdat er maar in één een bijregel staat.
        HStack(alignment: .top, spacing: BovexaTheme.Space.md) {
            GlassCard(padding: BovexaTheme.Space.md, emphasis: .quiet) {
                StatTile(
                    value: "\(viewModel.appointmentCount)",
                    label: "afspraken",
                    note: viewModel.awayNote,
                    systemImage: "calendar"
                )
            }
            GlassCard(padding: BovexaTheme.Space.md, emphasis: .quiet) {
                StatTile(
                    value: viewModel.plannedHoursText, label: "geplande uren",
                    systemImage: "clock", tint: BovexaTheme.Colors.categoryGreen
                )
            }
        }
    }

    private var timeline: some View {
        VStack(alignment: .leading, spacing: BovexaTheme.Space.sm) {
            SectionHeading(title: "Tijdlijn", systemImage: "clock.fill")

            GlassCard {
                if !viewModel.hasLoadedOnce {
                    ProgressView()
                        .tint(BovexaTheme.Colors.blue)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if viewModel.todayEvents.isEmpty {
                    EmptyStateView(systemImage: "calendar", text: "Nog niks gepland vandaag…")
                } else if let userId = currentUser?.id {
                    VStack(spacing: 0) {
                        ForEach(viewModel.todayEvents) { event in
                            let isLast = event.id == viewModel.todayEvents.last?.id

                            Button {
                                Haptics.selection()
                                selectedEvent = event
                            } label: {
                                AppointmentRow(
                                    event: event, currentUserId: userId,
                                    memberColors: viewModel.memberColors, labelStore: viewModel.labelStore,
                                    style: .timeline, isLast: isLast
                                )
                            }
                            .buttonStyle(.plain)

                            // Geen scheidingslijn tussen tijdlijnrijen: de lijn
                            // tussen de stippen doet dat werk al, en een streep
                            // dwars door die lijn knipt de dag in stukken.
                        }
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
    VandaagView()
        .environmentObject(AuthStore())
        .environmentObject(TabRouter())
}
