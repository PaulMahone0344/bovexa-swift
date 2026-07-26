import SwiftUI

/// Eén regel in "Dagtaken — <bedrijf>". Vinkje en wissen zijn alleen actief voor
/// eigen taken (valkuil E) — bij een taak van een collega tonen we ze uitgegrijsd
/// resp. helemaal niet, in plaats van ze onklikbaar maar normaal te laten ogen.
struct TeamTaskRowView: View {
    let task: AgendaTask
    let isMine: Bool
    let ownerLabel: String
    let onToggle: () -> Void
    let onDelete: () -> Void

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
                            .background(Circle().fill(isDone ? BovexaTheme.Colors.tealDark : Color.clear))
                            .frame(width: 22, height: 22)

                        if isDone {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(BovexaTheme.Colors.white)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(!isMine)
                .opacity(isMine ? 1 : 0.45)
                .padding(.top, 1)

                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(BovexaTheme.TypeStyle.subheadline.weight(.bold))
                        .foregroundStyle(isDone ? BovexaTheme.Colors.muted : BovexaTheme.Colors.ink)
                        .strikethrough(isDone)

                    if let notes = task.notes, !notes.isEmpty {
                        Text(notes)
                            .font(BovexaTheme.TypeStyle.footnote)
                            .foregroundStyle(BovexaTheme.Colors.muted)
                    }

                    Text(ownerLabel)
                        .font(BovexaTheme.TypeStyle.caption.weight(.bold))
                        .foregroundStyle(BovexaTheme.Colors.muted)

                    if let completedAt = task.completedAt {
                        Text(TaskCompletionFormatting.label(completedAt: completedAt))
                            .font(BovexaTheme.TypeStyle.caption.weight(.semibold))
                            .foregroundStyle(BovexaTheme.Colors.muted)
                    }
                }

                Spacer(minLength: BovexaTheme.Space.sm)

                if isMine {
                    Button("Wissen", action: onDelete)
                        .font(BovexaTheme.TypeStyle.footnote.weight(.bold))
                        .foregroundStyle(BovexaTheme.Colors.danger)
                }
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
                isMine: true, ownerLabel: "Jij", onToggle: {}, onDelete: {}
            )
            TeamTaskRowView(
                task: AgendaTask(id: "2", owner: "u2", org: "org1", title: "Klant bellen", notes: nil, status: .klaar, visibility: .company, viewers: [], created: Date(), updated: Date()),
                isMine: false, ownerLabel: "Karim", onToggle: {}, onDelete: {}
            )
        }
        .padding()
    }
}
