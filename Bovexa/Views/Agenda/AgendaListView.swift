import SwiftUI

/// Lijstweergave: komende afspraken per dag gegroepeerd.
struct AgendaListView: View {
    @ObservedObject var viewModel: AgendaViewModel
    let currentUserId: String
    let now: () -> Date
    @Binding var selectedEvent: AgendaEvent?

    var body: some View {
        ScrollView {
            let groups = ListViewGrouping.upcomingGroupedByDay(viewModel.events, from: now())

            VStack(alignment: .leading, spacing: BovexaTheme.Space.lg) {
                if !viewModel.hasLoadedOnce {
                    ProgressView()
                        .tint(BovexaTheme.Colors.blue)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, BovexaTheme.Space.xxl)
                } else if groups.isEmpty {
                    EmptyStateView(systemImage: "calendar", text: "Geen komende afspraken.")
                } else {
                    ForEach(groups) { group in
                        VStack(alignment: .leading, spacing: BovexaTheme.Space.sm) {
                            Text(EventHelpers.longDay(group.day))
                                .font(BovexaTheme.TypeStyle.headline)
                                .foregroundStyle(BovexaTheme.Colors.ink)

                            GlassCard {
                                VStack(spacing: 0) {
                                    ForEach(group.events) { event in
                                        Button {
                                            Haptics.selection()
                                            selectedEvent = event
                                        } label: {
                                            AppointmentRow(event: event, currentUserId: currentUserId, memberColors: viewModel.memberColors, labelStore: viewModel.labelStore)
                                        }
                                        .buttonStyle(.plain)

                                        if event.id != group.events.last?.id {
                                            Divider().overlay(BovexaTheme.Colors.edgeSoft)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(BovexaTheme.Space.xl)
            .padding(.bottom, 90)
        }
    }
}
