import SwiftUI

/// Concept-kaart: voorgestelde afspraak (categorie-stip, titel, tijd · locatie) vóór
/// bevestigen. Geport uit ConceptCard.tsx in ~/Desktop/agenda-app/src/components/chat/.
struct ConceptCardView: View {
    let appointment: ProposedAppointment

    private var meta: String {
        [appointment.start + " – " + appointment.end, appointment.location]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    var body: some View {
        GlassCard(padding: BovexaTheme.Space.md) {
            HStack(spacing: BovexaTheme.Space.md) {
                Circle()
                    .fill(BovexaTheme.categoryColor(for: appointment.category))
                    .frame(width: 10, height: 10)

                VStack(alignment: .leading, spacing: 3) {
                    Text(appointment.title)
                        .font(BovexaTheme.TypeStyle.subheadline.weight(.bold))
                        .foregroundStyle(BovexaTheme.Colors.ink)
                    Text(meta)
                        .font(BovexaTheme.TypeStyle.caption)
                        .foregroundStyle(BovexaTheme.Colors.muted)
                }

                Spacer()
            }
        }
    }
}

#Preview {
    ZStack {
        AppBackground()
        ConceptCardView(appointment: ProposedAppointment(
            title: "Tandarts", date: "2026-08-03", start: "09:00", end: "09:30",
            category: .body, location: "Amsterdam"
        ))
        .padding()
    }
}
