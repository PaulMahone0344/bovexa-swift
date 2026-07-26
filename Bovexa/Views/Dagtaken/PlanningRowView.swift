import SwiftUI

/// Eén regel in "Mijn dagtaken" of het archief — tekst tikken klapt in/uit, acties
/// eronder. In "Mijn dagtaken" is de derde actie "Archiveren" (`onArchive`); in het
/// archief is dat "Terugzetten" + een wis-actie met een dynamisch label (voor de
/// twee-tik-bevestiging, valkuil G) — zelfde component voor beide, zoals PlanningRow
/// in taken.tsx.
struct PlanningRowView: View {
    let note: PlanningNote
    let isEditing: Bool
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    let onToggleDone: () -> Void
    let onEdit: () -> Void
    var onArchive: (() -> Void)?
    var onRestore: (() -> Void)?
    var onDelete: () -> Void = {}
    var deleteLabel: String?

    private var trailingLabel: String { deleteLabel ?? (onArchive != nil ? "Archiveren" : "Wissen") }
    private var trailingAction: () -> Void { onArchive ?? onDelete }

    var body: some View {
        GlassCard(emphasis: isEditing ? .standard : .quiet) {
            VStack(alignment: .leading, spacing: BovexaTheme.Space.sm) {
                HStack(alignment: .top, spacing: BovexaTheme.Space.sm) {
                    Button(action: {
                        Haptics.selection()
                        onToggleDone()
                    }) {
                        ZStack {
                            Circle()
                                .strokeBorder(BovexaTheme.Colors.accent, lineWidth: 1.5)
                                .background(Circle().fill(note.done ? BovexaTheme.Colors.blueDeep : Color.clear))
                                .frame(width: 22, height: 22)

                            if note.done {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(BovexaTheme.Colors.white)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 1)

                    Button(action: {
                        Haptics.selection()
                        onToggleExpand()
                    }) {
                        HStack(alignment: .top, spacing: BovexaTheme.Space.sm) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(note.title)
                                    .font(BovexaTheme.TypeStyle.subheadline.weight(.bold))
                                    .foregroundStyle(note.done ? BovexaTheme.Colors.muted : BovexaTheme.Colors.ink)
                                    .strikethrough(note.done)
                                    .lineLimit(isExpanded ? nil : 1)

                                if !note.body.isEmpty {
                                    Text(note.body)
                                        .font(BovexaTheme.TypeStyle.footnote)
                                        .foregroundStyle(BovexaTheme.Colors.muted)
                                        .lineLimit(isExpanded ? nil : 2)
                                }

                                if let completedAt = note.completedAt {
                                    Text(TaskCompletionFormatting.label(completedAt: completedAt))
                                        .font(BovexaTheme.TypeStyle.caption.weight(.semibold))
                                        .foregroundStyle(BovexaTheme.Colors.muted)
                                }
                            }

                            Spacer(minLength: BovexaTheme.Space.sm)

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(BovexaTheme.Colors.muted)
                                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: BovexaTheme.Space.md) {
                    Spacer()

                    Button("Bewerken", action: onEdit)
                        .font(BovexaTheme.TypeStyle.footnote.weight(.bold))
                        .foregroundStyle(BovexaTheme.Colors.accent)

                    if let onRestore {
                        Button("Terugzetten", action: onRestore)
                            .font(BovexaTheme.TypeStyle.footnote.weight(.bold))
                            .foregroundStyle(BovexaTheme.Colors.accent)
                    }

                    Button(trailingLabel, action: trailingAction)
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
        PlanningRowView(
            note: PlanningNote(id: "1", title: "Bellen met klant", body: "Over de offerte van vorige week", done: false, createdAt: Date(), updatedAt: Date(), archived: false),
            isEditing: false, isExpanded: true, onToggleExpand: {}, onToggleDone: {}, onEdit: {}, onArchive: {}
        )
        .padding()
    }
}
