import SwiftUI

/// Kiezer voor "wiens agenda kijk ik" (m10 plak 2). Opgebouwd als de legenda: een
/// sheet met grote titel en dezelfde chevron-sluitknop, want dit is dezelfde soort
/// keuze — bepalen wát het raster laat zien.
///
/// Eén persoon tegelijk. Met twaalf leden naast elkaar in kolommen wordt een
/// telefoon onleesbaar, en een team-strip blijft bewust buiten de app.
struct AgendaPersoonKiezerView: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var memberColors: MemberColors
    let currentUserId: String
    let selected: String?
    let onPick: (String?) -> Void

    /// Alfabetisch, net als de ledenlijst bij Bedrijf — daar staat dezelfde groep
    /// mensen, dus dezelfde volgorde.
    private var sortedMembers: [Member] {
        memberColors.members.sorted {
            $0.naam.localizedCaseInsensitiveCompare($1.naam) == .orderedAscending
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: BovexaTheme.Space.lg) {
                        Text("Kies wie je wilt zien. De hele agenda volgt je keuze, ook de dagweergave.")
                            .font(BovexaTheme.TypeStyle.footnote)
                            .foregroundStyle(BovexaTheme.Colors.inkSoft)

                        GlassCard(padding: BovexaTheme.Space.md) {
                            VStack(spacing: 0) {
                                row(userId: nil, name: "Iedereen", color: nil)

                                if !sortedMembers.isEmpty {
                                    Divider().overlay(BovexaTheme.Colors.edgeSoft)
                                }

                                ForEach(Array(sortedMembers.enumerated()), id: \.element.id) { index, member in
                                    row(
                                        userId: member.userId,
                                        name: member.userId == currentUserId ? "\(member.naam) · jij" : member.naam,
                                        color: memberColors.color(for: member.userId)
                                    )
                                    if index != sortedMembers.count - 1 {
                                        Divider().overlay(BovexaTheme.Colors.edgeSoft)
                                    }
                                }
                            }
                        }
                    }
                    .padding(BovexaTheme.Space.xl)
                }
            }
            .navigationTitle("Agenda van")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "chevron.left") }
                        .accessibilityLabel("Sluiten")
                }
            }
        }
    }

    private func row(userId: String?, name: String, color: Color?) -> some View {
        Button {
            Haptics.selection()
            onPick(userId)
            dismiss()
        } label: {
            HStack(spacing: BovexaTheme.Space.md) {
                if let color {
                    Circle()
                        .fill(color)
                        .frame(width: 18, height: 18)
                        .overlay(Circle().strokeBorder(BovexaTheme.Colors.edge, lineWidth: 1))
                } else {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(BovexaTheme.Colors.accent)
                        .frame(width: 18, height: 18)
                }

                Text(name)
                    .font(BovexaTheme.TypeStyle.body.weight(.medium))
                    .foregroundStyle(BovexaTheme.Colors.ink)
                    .lineLimit(1)

                Spacer()

                if userId == selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(BovexaTheme.Colors.accent)
                }
            }
            .padding(.vertical, BovexaTheme.Space.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
