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
                .frame(width: 6)
                .frame(maxHeight: .infinity)

            // De kleurstreep alleen zegt niets zonder de naam eronder te lezen.
            // Een rondje met de initiaal in de persoonskleur is meteen leesbaar.
            // Ook bij je eigen afspraak, anders verspringt de tekstkolom per rij.
            ownerBadge

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

    private var ownerColor: Color { memberColors.color(for: event.owner) }

    /// Eerste letter van de voornaam; valt terug op een stip als de naam nog
    /// niet geladen is (leden komen later binnen dan de afspraken).
    private var ownerInitial: String? {
        guard let first = memberColors.firstName(for: event.owner)?.first else { return nil }
        return String(first).uppercased()
    }

    private var ownerBadge: some View {
        Circle()
            .fill(ownerColor.opacity(isColleague ? 0.22 : 0.14))
            .frame(width: 24, height: 24)
            .overlay(Circle().stroke(ownerColor.opacity(isColleague ? 0.75 : 0.4), lineWidth: 1.2))
            .overlay {
                if let initial = ownerInitial {
                    Text(initial)
                        .font(.system(.caption2, design: .rounded, weight: .bold))
                        .foregroundStyle(ownerColor)
                } else {
                    Circle().fill(ownerColor).frame(width: 6, height: 6)
                }
            }
            .accessibilityLabel(memberColors.firstName(for: event.owner) ?? "Onbekend")
    }
}
