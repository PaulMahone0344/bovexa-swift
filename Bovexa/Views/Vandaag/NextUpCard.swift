import SwiftUI

/// Hero-kaart bovenaan Vandaag: de eerstvolgende afspraak, of — als de dag
/// erop zit — een rustpunt in plaats van een gat.
///
/// Bestaat omdat elk vlak op Vandaag in v2 hetzelfde gewicht had; er was geen
/// enkel element dat de blik ving.
struct NextUpCard: View {
    let event: AgendaEvent?
    let hadEventsToday: Bool
    let currentUserId: String
    @ObservedObject var memberColors: MemberColors
    let onOpen: (AgendaEvent) -> Void

    var body: some View {
        if let event {
            Button {
                Haptics.selection()
                onOpen(event)
            } label: {
                upcoming(event)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else if hadEventsToday {
            dayDone
        }
    }

    private func upcoming(_ event: AgendaEvent) -> some View {
        GlassCard(padding: BovexaTheme.Space.xl, emphasis: .hero) {
            VStack(alignment: .leading, spacing: BovexaTheme.Space.md) {
                HStack {
                    Text("VOLGENDE AFSPRAAK")
                        .font(.system(.caption2, design: .rounded, weight: .bold))
                        .kerning(1.2)
                        .foregroundStyle(BovexaTheme.Colors.accent)

                    Spacer()

                    if let relative = relativeStart(event.start) {
                        Text(relative)
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundStyle(BovexaTheme.Colors.accent)
                            .padding(.horizontal, BovexaTheme.Space.sm)
                            .padding(.vertical, 3)
                            .background(
                                Capsule().fill(BovexaTheme.Colors.blue.opacity(0.18))
                            )
                    }
                }

                HStack(alignment: .firstTextBaseline, spacing: BovexaTheme.Space.md) {
                    // "Hele dag" past niet op 40pt naast de titel.
                    Text(EventHelpers.rowTimeText(event))
                        .font(.system(size: event.allDay ? 26 : 40, weight: .bold, design: .rounded))
                        .foregroundStyle(BovexaTheme.Colors.ink)
                        .monospacedDigit()
                        .lineLimit(1)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.title)
                            .font(BovexaTheme.TypeStyle.title3)
                            .foregroundStyle(BovexaTheme.Colors.ink)
                            .lineLimit(2)

                        Text(subtitle(event))
                            .font(BovexaTheme.TypeStyle.footnote)
                            .foregroundStyle(BovexaTheme.Colors.muted)
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var dayDone: some View {
        GlassCard(padding: BovexaTheme.Space.xl) {
            HStack(spacing: BovexaTheme.Space.md) {
                // Rondje eromheen, zoals de mockup: het losse maantje zweefde in de
                // kaart zonder gewicht naast de titel ernaast.
                Circle()
                    .fill(BovexaTheme.Colors.warm.opacity(0.16))
                    .frame(width: 52, height: 52)
                    .overlay {
                        Image(systemName: "moon.stars.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(BovexaTheme.Colors.warm)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Dag is rond")
                        .font(BovexaTheme.TypeStyle.title3)
                        .foregroundStyle(BovexaTheme.Colors.ink)
                    Text("Geen afspraken meer vandaag.")
                        .font(BovexaTheme.TypeStyle.footnote)
                        .foregroundStyle(BovexaTheme.Colors.muted)
                }

                Spacer()
            }
        }
    }

    /// "over 25 min" / "over 2 uur" — alleen binnen 8 uur, daarbuiten voegt
    /// het niets toe boven de kloktijd die er al staat.
    private func relativeStart(_ start: Date) -> String? {
        let minutes = Int(start.timeIntervalSinceNow / 60)
        guard minutes > 0, minutes <= 8 * 60 else { return nil }
        if minutes < 60 { return "over \(minutes) min" }
        let hours = minutes / 60
        return hours == 1 ? "over 1 uur" : "over \(hours) uur"
    }

    private func subtitle(_ event: AgendaEvent) -> String {
        var parts: [String] = []
        if event.owner != currentUserId, let name = memberColors.firstName(for: event.owner) {
            parts.append(name)
        }
        if let location = event.location, !location.isEmpty {
            parts.append(location)
        }
        parts.append(EventHelpers.rowDurationLabel(event))
        // Lege delen eruit, anders eindigt de regel op een losse " · " zodra er
        // geen duur is (hele dag, of een event zonder eindtijd).
        return parts.filter { !$0.isEmpty }.joined(separator: " · ")
    }
}
