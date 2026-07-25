import SwiftUI

/// Eén rij in de tijdlijn van vandaag of de "Volgende afspraak"-kaart.
struct AppointmentRow: View {
    let event: AgendaEvent
    let currentUserId: String
    @ObservedObject var memberColors: MemberColors

    private var isColleague: Bool { event.owner != currentUserId }

    var body: some View {
        HStack(spacing: BovexaTheme.Space.md) {
            Text(EventHelpers.fmtTime(event.start))
                .font(BovexaTheme.TypeStyle.footnote.weight(.semibold))
                .foregroundStyle(BovexaTheme.Colors.muted)
                .monospacedDigit()
                .frame(minWidth: 44, alignment: .leading)

            ZStack {
                if isColleague {
                    Circle()
                        .stroke(memberColors.color(for: event.owner), lineWidth: 2)
                        .frame(width: 14, height: 14)
                }
                Circle()
                    .fill(EventHelpers.eventColor(event))
                    .frame(width: 9, height: 9)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: BovexaTheme.Space.xs) {
                    Text(event.title)
                        .font(BovexaTheme.TypeStyle.body.weight(.medium))
                        .foregroundStyle(BovexaTheme.Colors.ink)
                        .lineLimit(1)
                    if isColleague, let firstName = memberColors.firstName(for: event.owner) {
                        Text(firstName)
                            .font(BovexaTheme.TypeStyle.caption.weight(.medium))
                            .foregroundStyle(memberColors.color(for: event.owner))
                    }
                }
                if let location = event.location, !location.isEmpty {
                    Text(location)
                        .font(BovexaTheme.TypeStyle.footnote)
                        .foregroundStyle(BovexaTheme.Colors.muted)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: BovexaTheme.Space.sm)

            Text(EventHelpers.durationLabel(event))
                .font(BovexaTheme.TypeStyle.footnote)
                .foregroundStyle(BovexaTheme.Colors.muted)
        }
        .padding(.vertical, BovexaTheme.Space.xs)
        .contentShape(Rectangle())
    }
}
