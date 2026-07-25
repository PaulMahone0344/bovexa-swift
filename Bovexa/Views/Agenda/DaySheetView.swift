import SwiftUI

/// Bodemsheet bij dag-tik in de maandweergave: daglijst + "Open dag"-knop.
/// Omlaag slepen of achtergrond tikken sluit hem (standaardgedrag van .sheet).
struct DaySheetView: View {
    let day: Date
    let events: [AgendaEvent]
    let currentUserId: String
    @ObservedObject var memberColors: MemberColors
    let onOpenDay: () -> Void
    let onSelectEvent: (AgendaEvent) -> Void

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
                        Text("Geen afspraken.")
                            .font(BovexaTheme.TypeStyle.body)
                            .foregroundStyle(BovexaTheme.Colors.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
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
                                            AppointmentRow(event: event, currentUserId: currentUserId, memberColors: memberColors)
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
