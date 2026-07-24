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
                .font(.system(size: BovexaTheme.TypeScale.small, weight: .semibold))
                .foregroundStyle(BovexaTheme.Colors.muted)
                .frame(width: 44, alignment: .leading)

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
                        .font(.system(size: BovexaTheme.TypeScale.body, weight: .medium))
                        .foregroundStyle(BovexaTheme.Colors.ink)
                        .lineLimit(1)
                    if isColleague, let firstName = memberColors.firstName(for: event.owner) {
                        Text(firstName)
                            .font(.system(size: BovexaTheme.TypeScale.tiny, weight: .medium))
                            .foregroundStyle(memberColors.color(for: event.owner))
                    }
                }
                if let location = event.location, !location.isEmpty {
                    Text(location)
                        .font(.system(size: BovexaTheme.TypeScale.small))
                        .foregroundStyle(BovexaTheme.Colors.muted)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: BovexaTheme.Space.sm)

            Text(EventHelpers.durationLabel(event))
                .font(.system(size: BovexaTheme.TypeScale.small))
                .foregroundStyle(BovexaTheme.Colors.muted)
        }
        .padding(.vertical, BovexaTheme.Space.xs)
        .contentShape(Rectangle())
    }
}
