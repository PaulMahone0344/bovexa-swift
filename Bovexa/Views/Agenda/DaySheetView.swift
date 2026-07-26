import SwiftUI

/// Bodemsheet bij dag-tik in de maandweergave: daglijst + "Open dag"-knop.
/// Omlaag slepen of achtergrond tikken sluit hem (standaardgedrag van .sheet).
struct DaySheetView: View {
    let day: Date
    let events: [AgendaEvent]
    let currentUserId: String
    @ObservedObject var memberColors: MemberColors
    @ObservedObject var labelStore: LabelStore
    let onOpenDay: () -> Void
    let onSelectEvent: (AgendaEvent) -> Void
    var onPlanAppointment: () -> Void = {}

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                VStack(spacing: BovexaTheme.Space.lg) {
                    HStack {
                        Text(EventHelpers.longDay(day))
                            .font(BovexaTheme.TypeStyle.headline)
                            .foregroundStyle(BovexaTheme.Colors.ink)
                        Spacer()
                        Button("Open dag", action: onOpenDay)
                            .font(BovexaTheme.TypeStyle.footnote.weight(.semibold))
                            .foregroundStyle(BovexaTheme.Colors.accent)
                    }

                    if events.isEmpty {
                        EmptyStateView(systemImage: "calendar", text: "Geen afspraken.", surface: .background)
                        Button {
                            Haptics.selection()
                            onPlanAppointment()
                        } label: {
                            Label("Afspraak plannen", systemImage: "plus")
                        }
                        .buttonStyle(.glassProminentBrand)
                        .frame(maxWidth: .infinity)
                        Spacer()
                    } else {
                        ScrollView {
                            GlassCard {
                                VStack(spacing: 0) {
                                    ForEach(events.sorted { $0.start < $1.start }) { event in
                                        Button {
                                            Haptics.selection()
                                            onSelectEvent(event)
                                        } label: {
                                            AppointmentRow(event: event, currentUserId: currentUserId, memberColors: memberColors, labelStore: labelStore)
                                        }
                                        .buttonStyle(.plain)

                                        if event.id != events.last?.id {
                                            Divider().overlay(BovexaTheme.Colors.edgeSoft)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(BovexaTheme.Space.xl)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
