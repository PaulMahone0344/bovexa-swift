import SwiftUI

/// "Toegewezen aan" — samenvattingsrij die open/dichtklapt naar een selecteerbare
/// ledenlijst; je kunt er meerdere aanvinken. Favorieten (bolletje) staan bovenaan;
/// vanaf 6 leden verschijnt een zoekbalk.
struct AssigneePickerView: View {
    let members: [Member]
    let currentUserId: String
    @Binding var selectedIds: [String]
    var disabled: Bool = false

    @State private var isOpen = false
    @State private var query = ""
    @State private var favorites: [String] = []

    private let favoritesStore = FavoritesStore()
    private static let searchFrom = 6

    private var shown: [Member] {
        MemberSearchHelpers.sortMembers(MemberSearchHelpers.filterMembers(members, query: query), favorites: favorites)
    }

    private var summary: String {
        if selectedIds.isEmpty { return "Niemand" }
        let names = members.filter { selectedIds.contains($0.userId) }.map { $0.naam.isEmpty ? $0.email : $0.naam }
        return names.isEmpty ? "\(selectedIds.count) gekozen" : names.joined(separator: ", ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BovexaTheme.Space.sm) {
            trigger
            if isOpen { expandedList }
        }
        .task { favorites = favoritesStore.load(userId: currentUserId) }
    }

    private var trigger: some View {
        Button { isOpen.toggle() } label: {
            HStack {
                Text(summary)
                    .font(BovexaTheme.TypeStyle.body.weight(.semibold))
                    .foregroundStyle(BovexaTheme.Colors.ink)
                    .lineLimit(1)
                Spacer()
                Image(systemName: isOpen ? "chevron.up" : "chevron.right")
                    .foregroundStyle(BovexaTheme.Colors.muted)
            }
            .padding(.horizontal, BovexaTheme.Space.md)
            .frame(minHeight: 44)
            .background(BovexaTheme.Colors.glass)
            .overlay(
                RoundedRectangle(cornerRadius: BovexaTheme.Radius.md, style: .continuous)
                    .strokeBorder(BovexaTheme.Colors.edge, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: BovexaTheme.Radius.md, style: .continuous))
        }
        .disabled(disabled)
    }

    @ViewBuilder
    private var expandedList: some View {
        if members.isEmpty {
            EmptyStateView(systemImage: "person.2", text: "Nog geen collega's in je bedrijf.")
        } else {
            VStack(alignment: .leading, spacing: BovexaTheme.Space.xs) {
                if members.count >= Self.searchFrom { searchField }

                if query.isEmpty {
                    memberRow(label: "Niemand", checked: selectedIds.isEmpty, onToggle: {
                        // De ledenrijen gaven wél terugkoppeling, deze niet (5b).
                        Haptics.selection()
                        selectedIds = []
                    })
                }

                if shown.isEmpty {
                    Text("Geen collega gevonden.")
                        .font(BovexaTheme.TypeStyle.subheadline)
                        .foregroundStyle(BovexaTheme.Colors.muted)
                } else {
                    ForEach(shown, id: \.userId) { member in
                        // Geen bolletje meer naast de naam: het vinkje links zegt
                        // al of iemand de taak krijgt, en een tweede markering
                        // ernaast leverde alleen de vraag op wat het verschil was.
                        // De favorietenvolgorde blijft, die bepaalt wie bovenaan staat.
                        memberRow(
                            label: member.naam.isEmpty ? member.email : member.naam,
                            checked: selectedIds.contains(member.userId),
                            onToggle: { toggle(member.userId) }
                        )
                    }
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: BovexaTheme.Space.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(BovexaTheme.Colors.muted)
            TextField("Zoek collega", text: $query)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .disabled(disabled)
        }
        .padding(.horizontal, BovexaTheme.Space.md)
        .frame(minHeight: 40)
        .background(BovexaTheme.Colors.glass)
        .overlay(
            RoundedRectangle(cornerRadius: BovexaTheme.Radius.md, style: .continuous)
                .strokeBorder(BovexaTheme.Colors.edge, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: BovexaTheme.Radius.md, style: .continuous))
    }

    private func toggle(_ userId: String) {
        Haptics.selection()
        selectedIds = selectedIds.contains(userId) ? selectedIds.filter { $0 != userId } : selectedIds + [userId]
    }

    private func star(_ userId: String) {
        favorites = MemberSearchHelpers.toggleFavorite(userId, in: favorites)
        favoritesStore.save(favorites, userId: currentUserId)
    }

    @ViewBuilder
    private func memberRow(label: String, checked: Bool, onToggle: @escaping () -> Void) -> some View {
        HStack(spacing: BovexaTheme.Space.sm) {
            Button(action: onToggle) {
                HStack(spacing: BovexaTheme.Space.sm) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(checked ? BovexaTheme.Colors.blueDeep : BovexaTheme.Colors.glass)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(checked ? BovexaTheme.Colors.blueDeep : BovexaTheme.Colors.edge, lineWidth: 1.5)
                            )
                            .frame(width: 22, height: 22)
                        if checked {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(BovexaTheme.Colors.white)
                        }
                    }
                    Text(label)
                        .font(BovexaTheme.TypeStyle.body.weight(.medium))
                        .foregroundStyle(BovexaTheme.Colors.ink)
                        .lineLimit(1)
                    Spacer()
                }
                // minHeight ín het label: de verticale padding stond buiten de
                // Button, dus die 18pt tussen twee rijen was dode ruimte.
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(disabled)
        }
    }
}
