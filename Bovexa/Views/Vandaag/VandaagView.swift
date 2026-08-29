import SwiftUI

struct VandaagView: View {
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var router: TabRouter
    @EnvironmentObject private var badgeStore: BadgeStore
    @StateObject private var viewModel = VandaagViewModel()
    @State private var selectedEvent: AgendaEvent?
    /// Tikken op de tegel "afspraken" klapt de tijden eronder in of uit. Staat
    /// standaard open: de lijst is sinds 26 augustus de enige plek op Vandaag
    /// waar je de afspraken van de dag ziet.
    @State private var toonAfspraken = true

    /// Eerste letter van je naam, als terugval wanneer er geen foto is.
    private var profielInitiaal: String {
        let naam = (currentUser?.naam ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let bron = naam.isEmpty ? (currentUser?.email ?? "") : naam
        guard let eerste = bron.first else { return "?" }
        return String(eerste).uppercased()
    }

    private var profielFoto: URL? {
        currentUser.flatMap { AvatarURLBuilder.url(userId: $0.id, avatar: $0.avatar) }
    }

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

                        // Hieronder stonden achtereenvolgens WeekBusyCard (eruit
                        // 26 juli) en OpenTasksCard: de kop "Dagtaken" met de open
                        // taken eronder. Ook eruit, op verzoek van de opdrachtgever
                        // — die lijst herhaalde de teller in `statsRow`, en die
                        // tegel brengt je met één tik naar het Dagtaken-tabblad.
                        // Beide kaarten blijven in de repo staan.
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
                        token: authStore.token ?? "", memberColors: viewModel.memberColors, labelStore: viewModel.labelStore,
                        // Terugklappen vuurt `.onAppear` hier niet opnieuw; zonder dit
                        // staat een verwijderde afspraak nog op Vandaag.
                        onChanged: { Task { await refresh() } },
                        onDeleted: { _ in Task { await refresh() } }
                    )
                }
            }
            // Geen systeemtitel: die staat vast links bovenin en laat het logo
            // niet boven zich toe. De kop is nu een eigen blok, zoals de mockup.
            .toolbar(.hidden, for: .navigationBar)
        }
        // Eén laadpad: `.task` draait al bij elke terugkeer naar deze tab. Met
        // `.onAppear { Task { refresh() } }` erbij liepen er twee load()'s
        // parallel — elk 3-4 verzoeken, en de eerste `defer` zette de spinner uit
        // terwijl de tweede nog liep.
        .task {
            await refresh()
        }
        .onAppear {
            // Dagtaken staan lokaal en kunnen op de andere tab veranderd zijn;
            // dit is goedkoop (UserDefaults) en hoeft niet op het netwerk te
            // wachten, dus los van refresh().
            if let userId = currentUser?.id { viewModel.reloadOpenTasks(userId: userId) }
        }
        .onChange(of: authStore.foregroundTick) { _, _ in
            Task { await refresh() }
        }
        // Voedt de tab-badge; geen extra netwerkverzoek, dit komt uit de load die
        // dit scherm toch al doet (6b).
        .onChange(of: viewModel.pendingAssignmentCount, initial: true) { _, count in
            badgeStore.setPendingAssignments(count)
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
                    RemoteLogoView(url: logoURL)
                        // Kleiner dan 118×24: daar hield het logo de titel eronder in
                        // evenwicht in plaats van eronder te blijven.
                        .frame(maxWidth: 96, maxHeight: 20)
                }
            }

            ZStack(alignment: .topTrailing) {
                // Links van en iets onder de avatar: op de oude plek (trailing,
                // y 8) verdween de zon volledig achter de profielfoto.
                VandaagHeaderArt()
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .offset(x: -60, y: 26)

                // Je eigen foto rechtsboven, zoals in de meeste apps: één tik naar
                // je profiel, en meteen te zien met welk account je binnen bent.
                Button {
                    Haptics.selection()
                    router.open(.profiel)
                } label: {
                    AvatarView(initial: profielInitiaal, url: profielFoto, size: 76)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Profiel")

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
            // Hoog genoeg voor foto én de lager gezette tekening: zonder dit
            // legden die zich over de kaart "Volgende afspraak" heen.
            .frame(minHeight: 96, alignment: .top)
        }
        .padding(.horizontal, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Vandaag, \(todayLine)")
    }

    /// Het aantal afspraken als rustige pil: informatie die je wel wilt zien,
    /// maar die de hero-kaart niet mag beconcurreren.
    ///
    /// "Geplande uren" stond hier tot 26 augustus ernaast, eruit op verzoek van de
    /// opdrachtgever. De tegel die overblijft is nu een knop: tikken klapt de
    /// afspraken met hun tijden eronder uit, zodat je ze ziet zonder eerst naar de
    /// tijdlijn te scrollen.
    /// Hetzelfde lijstje als in de kaart onderaan het scherm, alleen geteld:
    /// eigen taken plus die van het bedrijf.
    private var dagtaakAantal: Int {
        viewModel.dagtaakRegels(orgNaam: viewModel.memberColors.orgName).count
    }

    private var statsRow: some View {
        VStack(alignment: .leading, spacing: BovexaTheme.Space.sm) {
            // Stond tot nu in het tijdlijn-blok. Dat blok is eruit, dus de
            // melding hangt hier: dit is het enige plekje op Vandaag waar de
            // afspraken nog binnenkomen.
            if viewModel.loadFailed {
                LoadFailedNote(surface: .background)
            }

            HStack(alignment: .top, spacing: BovexaTheme.Space.sm) {
                Button {
                    Haptics.selection()
                    withAnimation(.snappy(duration: 0.22)) { toonAfspraken.toggle() }
                } label: {
                    GlassCard(padding: BovexaTheme.Space.md, emphasis: .quiet) {
                        HStack(alignment: .top, spacing: BovexaTheme.Space.sm) {
                            StatTile(
                                value: "\(viewModel.appointmentCount)",
                                label: "afspraken",
                                note: viewModel.awayNote,
                                systemImage: "calendar"
                            )
                            Image(systemName: "chevron.down")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(BovexaTheme.Colors.inkSoft)
                                .rotationEffect(.degrees(toonAfspraken ? 180 : 0))
                                .padding(.top, 6)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(viewModel.appointmentCount) afspraken")
                .accessibilityHint(toonAfspraken ? "Tik om de tijden te verbergen" : "Tik om de tijden te tonen")

                // Tweede teller ernaast: hoeveel dagtaken er nog open staan.
                // Die klapt niet uit — de lijst staat verderop op dit scherm al —
                // maar springt naar het Dagtaken-tabblad.
                Button {
                    Haptics.selection()
                    router.open(.dagtaken)
                } label: {
                    GlassCard(padding: BovexaTheme.Space.md, emphasis: .quiet) {
                        StatTile(
                            value: "\(dagtaakAantal)",
                            label: dagtaakAantal == 1 ? "dagtaak" : "dagtaken",
                            note: nil,
                            systemImage: "checkmark.circle"
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(dagtaakAantal) dagtaken")
                .accessibilityHint("Tik om naar Dagtaken te gaan")
            }

            if toonAfspraken {
                afsprakenUitklap
            }
        }
    }

    /// De afspraken van vandaag onder de tegel: dezelfde rijen als in de tijdlijn,
    /// maar compact — het gaat hier om tijd en titel, niet om de hele dag in beeld.
    @ViewBuilder
    private var afsprakenUitklap: some View {
        GlassCard(padding: BovexaTheme.Space.md, emphasis: .quiet) {
            if !viewModel.hasLoadedOnce {
                ProgressView()
                    .tint(BovexaTheme.Colors.blue)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if viewModel.todayEvents.isEmpty {
                EmptyStateView(systemImage: "calendar", text: "Nog niks gepland vandaag…")
            } else if let userId = currentUser?.id {
                VStack(spacing: BovexaTheme.Space.sm) {
                    ForEach(viewModel.todayEvents) { event in
                        Button {
                            Haptics.selection()
                            selectedEvent = event
                        } label: {
                            AppointmentRow(
                                event: event, currentUserId: userId,
                                memberColors: viewModel.memberColors, labelStore: viewModel.labelStore
                            )
                        }
                        .buttonStyle(.plain)

                        // Streep tussen de rijen: zonder scheiding lazen drie
                        // tijden onder elkaar als één blok. Niet onder de
                        // laatste — dat is de rand van de kaart al.
                        if event.id != viewModel.todayEvents.last?.id {
                            Divider()
                                .overlay(BovexaTheme.Colors.edge)
                        }
                    }
                }
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
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
