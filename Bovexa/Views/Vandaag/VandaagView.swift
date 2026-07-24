import SwiftUI

struct VandaagView: View {
    @EnvironmentObject private var authStore: AuthStore
    @StateObject private var viewModel = VandaagViewModel()
    @State private var selectedEventId: String?

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
                                Text("Volgende afspraak")
                                    .font(.system(size: BovexaTheme.TypeScale.title, weight: .semibold))
                                    .foregroundStyle(BovexaTheme.Colors.ink)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                GlassCard {
                                    Button {
                                        selectedEventId = EventHelpers.eventRecordId(next)
                                    } label: {
                                        AppointmentRow(event: next, currentUserId: userId, memberColors: viewModel.memberColors)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: BovexaTheme.Space.sm) {
                            Text("Tijdlijn")
                                .font(.system(size: BovexaTheme.TypeScale.title, weight: .semibold))
                                .foregroundStyle(BovexaTheme.Colors.ink)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            GlassCard {
                                if viewModel.todayEvents.isEmpty {
                                    Text("Nog niks gepland vandaag…")
                                        .font(.system(size: BovexaTheme.TypeScale.body))
                                        .foregroundStyle(BovexaTheme.Colors.muted)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                } else if let userId = currentUser?.id {
                                    VStack(spacing: 0) {
                                        ForEach(viewModel.todayEvents) { event in
                                            Button {
                                                selectedEventId = EventHelpers.eventRecordId(event)
                                            } label: {
                                                AppointmentRow(event: event, currentUserId: userId, memberColors: viewModel.memberColors)
                                            }
                                            .buttonStyle(.plain)

                                            if event.id != viewModel.todayEvents.last?.id {
                                                Divider().overlay(BovexaTheme.Colors.edge)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        WeekBusyCard(counts: viewModel.weekBusyCounts)
                    }
                    .padding(BovexaTheme.Space.xl)
                    .padding(.bottom, 90) // ruimte voor de zwevende tabbalk
                }
            }
            .navigationDestination(item: $selectedEventId) { id in
                EventDetailPlaceholderView(eventId: id)
            }
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
