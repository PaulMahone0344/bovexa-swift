import SwiftUI

/// Dagoverzicht onder de maandkalender: wat er op de aangetikte dag staat.
///
/// Vervangt de bodemsheet van m1 (26 juli). Die schoof over het scherm en moest
/// je weer wegklikken om verder te bladeren; de blokjes in een maandcel zijn te
/// klein om er de dag uit te lezen, dus dit is de plek waar je die dag echt ziet.
/// De lege ruimte onder de kalender was er toch al.
struct DayPanelView: View {
    let day: Date
    let events: [AgendaEvent]
    let currentUserId: String
    @ObservedObject var memberColors: MemberColors
    @ObservedObject var labelStore: LabelStore
    let onOpenDay: () -> Void
    let onSelectEvent: (AgendaEvent) -> Void
    let onPlanAppointment: () -> Void

    private var sorted: [AgendaEvent] {
        events.sorted { $0.start < $1.start }
    }

    /// "2 afspraken · 3 uur" — hetzelfde rekenwerk als op Vandaag, zodat een dag
    /// overal dezelfde cijfers geeft.
    private var summary: String {
        let count = VandaagStats.timedCount(events)
        let hours = VandaagStats.formatHours(VandaagStats.plannedHours(events))
        let appointments = count == 1 ? "1 afspraak" : "\(count) afspraken"
        return count == 0 ? "Niets gepland" : "\(appointments) · \(hours)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BovexaTheme.Space.sm) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(EventHelpers.longDay(day))
                        .font(BovexaTheme.TypeStyle.headline)
                        .foregroundStyle(BovexaTheme.Colors.ink)
                    Text(summary)
                        .font(BovexaTheme.TypeStyle.caption)
                        .foregroundStyle(BovexaTheme.Colors.inkSoft)
                }

                Spacer()

                // Was een kale tekstknop van ~55x18pt die als link las.
                Button("Open dag") {
                    Haptics.selection()
                    onOpenDay()
                }
                .buttonStyle(.glassSecondaryBrand)
            }

            // Boven de lijst (6d, besluit Ibrahim 19 aug): onderaan viel hij bij
            // vier of meer afspraken onder de vouw van de .medium-detent, terwijl
            // dit juist de actie is waarvoor je de dagsheet opent. "Open dag"
            // blijft secundair. NB: in M12 gaat deze knop naar de keuzesheet
            // "Nieuwe afspraak" (AI of handmatig) — de plek klopt dan al.
            planButton

            GlassCard {
                if sorted.isEmpty {
                    EmptyStateView(systemImage: "calendar", text: "Geen afspraken.")
                } else {
                    VStack(spacing: 0) {
                        ForEach(sorted) { event in
                            Button {
                                Haptics.selection()
                                onSelectEvent(event)
                            } label: {
                                AppointmentRow(
                                    event: event, currentUserId: currentUserId,
                                    memberColors: memberColors, labelStore: labelStore
                                )
                            }
                            .buttonStyle(.plain)

                            if event.id != sorted.last?.id {
                                Divider().overlay(BovexaTheme.Colors.edgeSoft)
                            }
                        }

                    }
                }
            }
        }
    }

    private var planButton: some View {
        Button {
            Haptics.selection()
            onPlanAppointment()
        } label: {
            Label("Afspraak plannen", systemImage: "plus")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminentBrand)
    }
}
