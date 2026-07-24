import SwiftUI

/// Alleen-lezen afspraak-detail: titel, categorie-kleur, dag+tijd, locatie,
/// klant-regel, notitie, "Van <voornaam>" bij andermans afspraak. Geen
/// bewerken/verwijderen/toewijzen/zichtbaarheid — dat komt in latere milestones.
/// Terug-knop komt gratis mee via NavigationStack.
struct EventDetailView: View {
    let event: AgendaEvent
    let currentUserId: String
    @ObservedObject var memberColors: MemberColors

    private var isColleague: Bool { event.owner != currentUserId }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                GlassCard {
                    VStack(alignment: .leading, spacing: BovexaTheme.Space.md) {
                        HStack(spacing: BovexaTheme.Space.sm) {
                            Circle()
                                .fill(EventHelpers.eventColor(event))
                                .frame(width: 12, height: 12)
                            Text(event.title)
                                .font(.system(size: BovexaTheme.TypeScale.h2, weight: .bold))
                                .foregroundStyle(BovexaTheme.Colors.ink)
                        }

                        if isColleague, let firstName = memberColors.firstName(for: event.owner) {
                            Text("Van \(firstName)")
                                .font(.system(size: BovexaTheme.TypeScale.small, weight: .medium))
                                .foregroundStyle(memberColors.color(for: event.owner))
                        }

                        Divider().overlay(BovexaTheme.Colors.edge)

                        detailRow(icon: "calendar", text: EventHelpers.longDay(event.start))
                        detailRow(icon: "clock", text: EventHelpers.detailTimeText(event))

                        if let location = event.location, !location.isEmpty {
                            detailRow(icon: "mappin.and.ellipse", text: location)
                        }

                        if let klant = event.klantNaam, !klant.isEmpty {
                            detailRow(icon: "person", text: klant)
                        }

                        if let notes = event.notes, !notes.isEmpty {
                            Divider().overlay(BovexaTheme.Colors.edge)
                            Text(notes)
                                .font(.system(size: BovexaTheme.TypeScale.body))
                                .foregroundStyle(BovexaTheme.Colors.inkSoft)
                        }
                    }
                }
                .padding(BovexaTheme.Space.xl)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func detailRow(icon: String, text: String) -> some View {
        HStack(spacing: BovexaTheme.Space.sm) {
            Image(systemName: icon)
                .foregroundStyle(BovexaTheme.Colors.muted)
                .frame(width: 20)
            Text(text)
                .font(.system(size: BovexaTheme.TypeScale.body))
                .foregroundStyle(BovexaTheme.Colors.ink)
        }
    }
}
