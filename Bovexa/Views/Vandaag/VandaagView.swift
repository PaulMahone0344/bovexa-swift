import SwiftUI

struct VandaagView: View {
    @EnvironmentObject private var authStore: AuthStore
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
                        HStack(alignment: .center) {
                            // `muted` staat hier direct op de ondergrond, niet op
                            // glas: sinds de v4-orbs is die ondergrond op deze plek
                            // verzadigd teal en haalde muted nog maar 2.4:1.
                            // `inkSoft` houdt het rustig én leesbaar.
                            Text(todayLine)
                                .font(BovexaTheme.TypeStyle.subheadline)
                                .foregroundStyle(BovexaTheme.Colors.inkSoft)

                            Spacer()

                            // Het bedrijfslogo stond als brede banner midden in
                            // het scherm en domineerde de compositie; hier is het
                            // een rustig merkteken op de kopregel.
                            //
                            // Het is een upload van het bedrijf zelf, dus de
                            // kleuren liggen niet vast en botsen soms met het
                            // teal-palet. Een eigen glasplaatje eronder geeft het
                            // een eigen vlak, zodat het als merkteken leest en
                            // niet als een losse afbeelding die op de ondergrond
                            // zweeft. Niet grijs maken: dat verminkt huisstijlen
                            // die wél kloppen.
                            if let logoURL = viewModel.orgLogoURL {
                                AsyncImage(url: logoURL) { image in
                                    image.resizable().scaledToFit()
                                } placeholder: {
                                    Color.clear
                                }
                                .frame(maxWidth: 116, maxHeight: 22)
                                .padding(.horizontal, BovexaTheme.Space.sm)
                                .padding(.vertical, BovexaTheme.Space.xs)
                                .background(BovexaTheme.Colors.glassStrong, in: Capsule())
                                .overlay(Capsule().stroke(BovexaTheme.Colors.edgeSoft, lineWidth: 0.8))
                            }
                        }
                        .padding(.horizontal, 2)

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

                        WeekBusyCard(counts: viewModel.weekBusyCounts)
                    }
                    .padding(BovexaTheme.Space.xl)
                    .padding(.bottom, 120) // ruimte voor de tabbalk onderin
                    .animation(.smooth(duration: 0.3), value: viewModel.nextEvent?.id)
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
            .navigationTitle("Vandaag")
            .navigationBarTitleDisplayMode(.large)
        }
        .task {
            await refresh()
        }
        .onAppear {
            Task { await refresh() }
        }
    }

    /// Twee cijfers naast elkaar als rustige pillen: informatie die je wel wilt
    /// zien, maar die de hero-kaart niet mag beconcurreren.
    private var statsRow: some View {
        HStack(spacing: BovexaTheme.Space.md) {
            GlassCard(padding: BovexaTheme.Space.md, emphasis: .quiet) {
                StatTile(value: "\(viewModel.appointmentCount)", label: "afspraken")
            }
            GlassCard(padding: BovexaTheme.Space.md, emphasis: .quiet) {
                StatTile(value: viewModel.plannedHoursText, label: "geplande uren")
            }
        }
    }

    private var timeline: some View {
        VStack(alignment: .leading, spacing: BovexaTheme.Space.sm) {
            Text("Tijdlijn")
                .font(BovexaTheme.TypeStyle.headline)
                .foregroundStyle(BovexaTheme.Colors.ink)
                .frame(maxWidth: .infinity, alignment: .leading)

            GlassCard {
                if !viewModel.hasLoadedOnce {
                    ProgressView()
                        .tint(BovexaTheme.Colors.teal)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if viewModel.todayEvents.isEmpty {
                    EmptyStateView(systemImage: "calendar", text: "Nog niks gepland vandaag…")
                } else if let userId = currentUser?.id {
                    VStack(spacing: 0) {
                        ForEach(viewModel.todayEvents) { event in
                            Button {
                                Haptics.selection()
                                selectedEvent = event
                            } label: {
                                AppointmentRow(event: event, currentUserId: userId, memberColors: viewModel.memberColors)
                            }
                            .buttonStyle(.plain)

                            if event.id != viewModel.todayEvents.last?.id {
                                Divider().overlay(BovexaTheme.Colors.edgeSoft)
                            }
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
    VandaagView().environmentObject(AuthStore())
}
