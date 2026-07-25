import SwiftUI

/// Eén rij in de tijdlijn van vandaag.
///
/// v3: tijd links in rounded cijfers als anker, daarnaast een verticale
/// kleurstreep in de categoriekleur (met de persoonskleur eromheen bij een
/// afspraak van een collega). De v2-rij gebruikte twee gestapelde cirkels,
/// wat op een volle dag als ruis las.
struct AppointmentRow: View {
    let event: AgendaEvent
    let currentUserId: String
    @ObservedObject var memberColors: MemberColors

    private var isColleague: Bool { event.owner != currentUserId }

    var body: some View {
        HStack(spacing: BovexaTheme.Space.md) {
            // Vaste breedte i.p.v. minWidth: "Hele dag" is breder dan "10:00" en
            // zou anders de kleurstrepen per rij laten verspringen.
            Text(EventHelpers.rowTimeText(event))
                .font(event.allDay
                      ? .system(.caption, design: .rounded, weight: .semibold)
                      : .system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(BovexaTheme.Colors.inkSoft)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: 54, alignment: .leading)

            Capsule()
                .fill(EventHelpers.eventColor(event))
                .frame(width: 4)
                .frame(maxHeight: .infinity)
                .overlay(alignment: .leading) {
                    if isColleague {
                        Capsule()
                            .stroke(memberColors.color(for: event.owner), lineWidth: 1.5)
                            .frame(width: 4)
                    }
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(event.title)
                    .font(BovexaTheme.TypeStyle.body.weight(.semibold))
                    .foregroundStyle(BovexaTheme.Colors.ink)
                    .lineLimit(1)

                HStack(spacing: BovexaTheme.Space.xs) {
                    if isColleague, let firstName = memberColors.firstName(for: event.owner) {
                        Text(firstName)
                            .font(BovexaTheme.TypeStyle.caption.weight(.semibold))
                            .foregroundStyle(memberColors.color(for: event.owner))
                    }
                    if let location = event.location, !location.isEmpty {
                        Text(location)
                            .font(BovexaTheme.TypeStyle.footnote)
                            .foregroundStyle(BovexaTheme.Colors.muted)
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: BovexaTheme.Space.sm)

            Text(EventHelpers.rowDurationLabel(event))
                .font(BovexaTheme.TypeStyle.caption)
                .foregroundStyle(BovexaTheme.Colors.muted)
        }
        .padding(.vertical, BovexaTheme.Space.sm)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
}
