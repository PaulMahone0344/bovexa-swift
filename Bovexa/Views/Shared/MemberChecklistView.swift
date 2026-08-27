import SwiftUI

/// Vinkjeslijst met de collega's uit het bedrijf, altijd open. Hangt in de
/// afspraak-editor onder de knop van het bedrijf, waar bij Privé de contactenlijst
/// staat: onder "Wie kan dit zien?" hoort te staan wie je daar kunt aanwijzen, en
/// dat zijn bij een bedrijfsafspraak je collega's — dezelfde indeling als op het
/// scherm Mensen (privé = je contacten, bedrijf = wie een account heeft).
///
/// Aanvinken zet iemand op de afspraak, zodat die op zijn scherm verschijnt.
struct MemberChecklistView: View {
    let members: [Member]
    /// Jezelf: je staat wel in de lijst maar zonder "· jij" hoef je niet te raden
    /// welke van de twee Aymans je bent.
    let currentUserId: String
    @Binding var selectedIds: [String]
    var disabled: Bool = false

    private var gesorteerd: [Member] {
        members.sorted { links, rechts in
            let l = links.naam.isEmpty ? links.email : links.naam
            let r = rechts.naam.isEmpty ? rechts.email : rechts.naam
            return l.localizedCaseInsensitiveCompare(r) == .orderedAscending
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BovexaTheme.Space.xs) {
            if members.isEmpty {
                Text("Nog geen collega's in je bedrijf.")
                    .font(BovexaTheme.TypeStyle.subheadline)
                    .foregroundStyle(BovexaTheme.Colors.muted)
                    .padding(.horizontal, BovexaTheme.Space.md)
            } else {
                ForEach(gesorteerd, id: \.userId) { member in
                    rij(member)
                }
            }
        }
    }

    private func rij(_ member: Member) -> some View {
        let naam = member.naam.isEmpty ? member.email : member.naam
        let label = member.userId == currentUserId ? "\(naam) · jij" : naam
        let gekozen = selectedIds.contains(member.userId)

        return Button {
            Haptics.selection()
            if gekozen {
                selectedIds.removeAll { $0 == member.userId }
            } else {
                selectedIds.append(member.userId)
            }
        } label: {
            HStack(spacing: BovexaTheme.Space.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(gekozen ? BovexaTheme.Colors.blueDeep : BovexaTheme.Colors.glass)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(gekozen ? BovexaTheme.Colors.blueDeep : BovexaTheme.Colors.edge, lineWidth: 1.5)
                        )
                        .frame(width: 22, height: 22)
                    if gekozen {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(BovexaTheme.Colors.white)
                    }
                }
                Text(label)
                    .font(BovexaTheme.TypeStyle.body)
                    .foregroundStyle(BovexaTheme.Colors.ink)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, BovexaTheme.Space.md)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}
