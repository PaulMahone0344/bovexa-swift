import SwiftUI

struct VandaagView: View {
    @EnvironmentObject private var authStore: AuthStore
    @StateObject private var viewModel = VandaagViewModel()
    @State private var selectedEvent: AgendaEvent?

    private var currentUser: AgendaUser? {
        if case .loggedIn(let user) = authStore.phase { return user }
        return nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(spacing: BovexaTheme.Space.lg) {
                        if let logoURL = viewModel.orgLogoURL {
                            AsyncImage(url: logoURL) { image in
                                image.resizable().scaledToFit()
                            } placeholder: {
                                Color.clear
                            }
                            .frame(height: 48)
                        }

                        GlassCard {
                            HStack {
                                StatTile(value: "\(viewModel.appointmentCount)", label: "afspraken")
                                StatTile(value: viewModel.plannedHoursText, label: "geplande uren")
                            }
                        }

                        if let next = viewModel.nextEvent, let userId = currentUser?.id {
                            VStack(alignment: .leading, spacing: BovexaTheme.Space.sm) {
                                Label {
                                    Text("Volgende afspraak")
                                        .font(BovexaTheme.TypeStyle.headline)
                                        .foregroundStyle(BovexaTheme.Colors.ink)
                                } icon: {
                                    Image(systemName: "clock")
                                        .font(BovexaTheme.TypeStyle.headline)
                                        .foregroundStyle(BovexaTheme.Colors.teal)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                                // Belangrijkste kaart op het scherm: prominenter glas via een
                                // extra teal glow bovenop GlassCard's eigen schaduw (design-taal:
                                // "belangrijke kaarten prominenter glas, lijst-rijen subtieler").
                                GlassCard {
                                    Button {
                                        Haptics.selection()
                                        selectedEvent = next
                                    } label: {
                                        AppointmentRow(event: next, currentUserId: userId, memberColors: viewModel.memberColors)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .shadow(
                                    color: BovexaTheme.Shadow.tealGlowColor.opacity(BovexaTheme.Shadow.tealGlowOpacity),
                                    radius: BovexaTheme.Shadow.tealGlowRadius,
                                    x: 0,
                                    y: BovexaTheme.Shadow.tealGlowOffsetY
                                )
                            }
                            .transition(.opacity)
                        }

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

                        WeekBusyCard(counts: viewModel.weekBusyCounts)
                    }
                    .padding(BovexaTheme.Space.xl)
                    .padding(.bottom, 90) // ruimte voor de tabbalk onderin
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

    private func refresh() async {
        guard let user = currentUser else { return }
        await viewModel.load(userId: user.id, orgId: user.defaultOrg, token: authStore.token ?? "")
    }
}

#Preview {
    VandaagView().environmentObject(AuthStore())
}
