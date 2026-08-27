import SwiftUI

/// Eén regel in "Dagtaken — <bedrijf>". Vinkje links (ook voor een collega bij een
/// gedeelde taak — wie hem doet, vinkt hem af), en de rij zelf opent het detail.
/// Wissen zit sinds 27 juli alleen nog in dat detailscherm: de rode knop trok in
/// een lijst waar je meestal alleen afvinkt alle aandacht naar zich toe.
struct TeamTaskRowView: View {
    let task: AgendaTask
    let canToggle: Bool
    let ownerLabel: String
    /// Namen van de mensen aan wie de taak is toegewezen (viewers, zonder de
    /// eigenaar zelf). Leeg = een taak voor het hele bedrijf, dan staat er niets.
    var assigneeLabel: String = ""
    /// Wie de taak heeft afgevinkt. Leeg als dat niet te herleiden is (een taak
    /// voor het hele team); dan blijft alleen het tijdstip staan.
    var afgevinktDoor: String = ""
    let onToggle: () -> Void
    let onOpen: () -> Void

    private var isDone: Bool { task.status == .klaar }

    var body: some View {
        GlassCard(emphasis: .quiet) {
            HStack(alignment: .top, spacing: BovexaTheme.Space.sm) {
                Button(action: {
                    Haptics.selection()
                    onToggle()
                }) {
                    ZStack {
                        Circle()
                            .strokeBorder(BovexaTheme.Colors.accent, lineWidth: 1.5)
                            .background(Circle().fill(isDone ? BovexaTheme.Colors.blueDeep : Color.clear))
                            .frame(width: 22, height: 22)

                        if isDone {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(BovexaTheme.Colors.white)
                        }
                    }
                    // Een vinkje van 22 punten is krap om te raken naast een rij die
                    // zelf ook reageert; dit vergroot het raakvlak zonder het beeld
                    // te veranderen.
                    .frame(width: 40, height: 44, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!canToggle)
                .opacity(canToggle ? 1 : 0.45)
                .accessibilityLabel(isDone ? "Afvinken ongedaan maken" : "Afvinken")

                Button(action: {
                    Haptics.selection()
                    onOpen()
                }) {
                    HStack(alignment: .top, spacing: BovexaTheme.Space.sm) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(task.title)
                                .font(BovexaTheme.TypeStyle.subheadline.weight(.bold))
                                .foregroundStyle(isDone ? BovexaTheme.Colors.muted : BovexaTheme.Colors.ink)
                                .strikethrough(isDone)
                                .multilineTextAlignment(.leading)

                            if let notes = task.notes, !notes.isEmpty {
                                Text(notes)
                                    .font(BovexaTheme.TypeStyle.footnote)
                                    .foregroundStyle(BovexaTheme.Colors.muted)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(1)
                            }

                            if !assigneeLabel.isEmpty {
                                Label(assigneeLabel, systemImage: "person.fill")
                                    .font(BovexaTheme.TypeStyle.caption.weight(.semibold))
                                    .foregroundStyle(BovexaTheme.Colors.accent)
                                    .lineLimit(1)
                            }

                            Text(TaskAuthorFormatting.shortLabel(owner: ownerLabel, created: task.created))
                                .font(BovexaTheme.TypeStyle.caption.weight(.bold))
                                .foregroundStyle(BovexaTheme.Colors.muted)

                            if let completedAt = task.completedAt {
                                Label(
                                    TaskCompletionFormatting.label(completedAt: completedAt, door: afgevinktDoor),
                                    systemImage: "checkmark.circle.fill"
                                )
                                .font(BovexaTheme.TypeStyle.caption.weight(.semibold))
                                .foregroundStyle(BovexaTheme.Colors.categoryGreen)
                            }
                        }

                        Spacer(minLength: BovexaTheme.Space.sm)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(BovexaTheme.Colors.muted)
                            .padding(.top, 2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    ZStack {
        AppBackground()
        VStack(spacing: BovexaTheme.Space.sm) {
            TeamTaskRowView(
                task: AgendaTask(id: "1", owner: "u1", org: "org1", title: "Voorraad tellen", notes: "Voor vrijdag", status: .open, visibility: .company, viewers: [], created: Date(), updated: Date()),
                canToggle: true, ownerLabel: "Jij", onToggle: {}, onOpen: {}
            )
            TeamTaskRowView(
                task: AgendaTask(id: "2", owner: "u2", org: "org1", title: "Klant bellen", notes: nil, status: .klaar, visibility: .company, viewers: [], created: Date(), updated: Date(), completedAt: Date()),
                canToggle: true, ownerLabel: "Karim", onToggle: {}, onOpen: {}
            )
        }
        .padding()
    }
}
