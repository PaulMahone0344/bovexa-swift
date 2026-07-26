import SwiftUI

/// Kiezer voor "wie zie ik in de agenda" (m10 plak 2, omgedraaid op 26 juli).
/// Opgebouwd als de legenda: een sheet met grote titel en dezelfde chevron-
/// sluitknop, want dit is dezelfde soort keuze — bepalen wát het raster laat zien.
///
/// Aanvinken in plaats van één persoon kiezen. Je eigen agenda staat bovenaan,
/// staat altijd aan en is niet uit te vinken: de Agenda begint bij jouw dag.
/// De sheet blijft open terwijl je vinkt, anders moet je hem per collega opnieuw
/// openen.
struct AgendaPersoonKiezerView: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var memberColors: MemberColors
    let currentUserId: String
    let selected: Set<String>
    let onToggle: (String) -> Void
    let onSelectEveryone: () -> Void
    let onSelectOnlyMe: () -> Void

    /// Alfabetisch, net als de ledenlijst bij Bedrijf — daar staat dezelfde groep
    /// mensen, dus dezelfde volgorde. Jezelf staat apart bovenaan.
    private var colleagues: [Member] {
        memberColors.members
            .filter { $0.userId != currentUserId }
            .sorted { $0.naam.localizedCaseInsensitiveCompare($1.naam) == .orderedAscending }
    }

    private var allSelected: Bool {
        !colleagues.isEmpty && colleagues.allSatisfy { selected.contains($0.userId) }
    }

    private var ownName: String {
        memberColors.members.first { $0.userId == currentUserId }?.naam ?? "Jouw agenda"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: BovexaTheme.Space.lg) {
                        Text("Je eigen agenda zie je altijd. Vink aan wie je er verder bij wilt zien; de hele agenda volgt je keuze, ook de dagweergave.")
                            .font(BovexaTheme.TypeStyle.footnote)
                            .foregroundStyle(BovexaTheme.Colors.inkSoft)

                        GlassCard(padding: BovexaTheme.Space.md) {
                            VStack(spacing: 0) {
                                ownRow

                                if !colleagues.isEmpty {
                                    Divider().overlay(BovexaTheme.Colors.edgeSoft)

                                    ForEach(Array(colleagues.enumerated()), id: \.element.id) { index, member in
                                        colleagueRow(member)
                                        if index != colleagues.count - 1 {
                                            Divider().overlay(BovexaTheme.Colors.edgeSoft)
                                        }
                                    }
                                }
                            }
                        }

                        if !colleagues.isEmpty {
                            HStack(spacing: BovexaTheme.Space.sm) {
                                Button(allSelected ? "Alleen ikzelf" : "Iedereen") {
                                    Haptics.selection()
                                    if allSelected { onSelectOnlyMe() } else { onSelectEveryone() }
                                }
                                .buttonStyle(.glassSecondaryBrand)
                                Spacer()
                            }
                        }
                    }
                    .padding(BovexaTheme.Space.xl)
                }
            }
            .navigationTitle("Wie zie je")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "chevron.left") }
                        .accessibilityLabel("Sluiten")
                }
            }
        }
    }

    /// Vast aangevinkt en niet aantikbaar; het vinkje staat er om te laten zien dat
    /// je eigen agenda meedoet, niet om er iets aan te veranderen.
    private var ownRow: some View {
        HStack(spacing: BovexaTheme.Space.md) {
            Circle()
                .fill(memberColors.color(for: currentUserId))
                .frame(width: 18, height: 18)
                .overlay(Circle().strokeBorder(BovexaTheme.Colors.edge, lineWidth: 1))

            VStack(alignment: .leading, spacing: 1) {
                Text("\(ownName) · jij")
                    .font(BovexaTheme.TypeStyle.body.weight(.medium))
                    .foregroundStyle(BovexaTheme.Colors.ink)
                    .lineLimit(1)
                Text("Altijd zichtbaar")
                    .font(BovexaTheme.TypeStyle.caption)
                    .foregroundStyle(BovexaTheme.Colors.muted)
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(BovexaTheme.Colors.accent)
        }
        .padding(.vertical, BovexaTheme.Space.sm)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(ownName), jouw eigen agenda, altijd zichtbaar")
    }

    private func colleagueRow(_ member: Member) -> some View {
        let isOn = selected.contains(member.userId)
        return Button {
            Haptics.selection()
            onToggle(member.userId)
        } label: {
            HStack(spacing: BovexaTheme.Space.md) {
                Circle()
                    .fill(memberColors.color(for: member.userId))
                    .frame(width: 18, height: 18)
                    .overlay(Circle().strokeBorder(BovexaTheme.Colors.edge, lineWidth: 1))

                Text(member.naam)
                    .font(BovexaTheme.TypeStyle.body.weight(.medium))
                    .foregroundStyle(BovexaTheme.Colors.ink)
                    .lineLimit(1)

                Spacer()

                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(isOn ? BovexaTheme.Colors.accent : BovexaTheme.Colors.muted)
            }
            .padding(.vertical, BovexaTheme.Space.sm)
            // Zonder dit is alleen de tekst raakbaar; de rest van de rij is glas en
            // glas telt niet mee voor hit-testing.
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(member.naam)
        .accessibilityValue(isOn ? "Zichtbaar" : "Verborgen")
    }
}
