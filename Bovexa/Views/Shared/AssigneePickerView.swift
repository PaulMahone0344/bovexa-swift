import SwiftUI

/// "Toegewezen aan" — samenvattingsrij die open/dichtklapt naar een selecteerbare
/// ledenlijst. Favorieten (ster) staan bovenaan; vanaf 6 leden verschijnt een zoekbalk.
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
                    .font(.system(size: BovexaTheme.TypeScale.body, weight: .semibold))
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
            Text("Nog geen collega's in je bedrijf.")
                .font(.system(size: BovexaTheme.TypeScale.small))
                .foregroundStyle(BovexaTheme.Colors.muted)
        } else {
            VStack(alignment: .leading, spacing: BovexaTheme.Space.xs) {
                if members.count >= Self.searchFrom { searchField }

                if query.isEmpty {
                    memberRow(label: "Niemand", checked: selectedIds.isEmpty, starred: nil, onToggle: { selectedIds = [] })
                }

                if shown.isEmpty {
                    Text("Geen collega gevonden.")
                        .font(.system(size: BovexaTheme.TypeScale.small))
                        .foregroundStyle(BovexaTheme.Colors.muted)
                } else {
                    ForEach(shown, id: \.userId) { member in
                        memberRow(
                            label: member.naam.isEmpty ? member.email : member.naam,
                            checked: selectedIds.contains(member.userId),
                            starred: favorites.contains(member.userId),
                            onToggle: { toggle(member.userId) },
                            onStar: { star(member.userId) }
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
        selectedIds = selectedIds.contains(userId) ? selectedIds.filter { $0 != userId } : selectedIds + [userId]
    }

    private func star(_ userId: String) {
        favorites = MemberSearchHelpers.toggleFavorite(userId, in: favorites)
        favoritesStore.save(favorites, userId: currentUserId)
    }

    @ViewBuilder
    private func memberRow(label: String, checked: Bool, starred: Bool?, onToggle: @escaping () -> Void, onStar: (() -> Void)? = nil) -> some View {
        HStack(spacing: BovexaTheme.Space.sm) {
            Button(action: onToggle) {
                HStack(spacing: BovexaTheme.Space.sm) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(checked ? BovexaTheme.Colors.tealDark : BovexaTheme.Colors.glass)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(checked ? BovexaTheme.Colors.tealDark : BovexaTheme.Colors.edge, lineWidth: 1.5)
                            )
                            .frame(width: 22, height: 22)
                        if checked {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(BovexaTheme.Colors.white)
                        }
                    }
                    Text(label)
                        .font(.system(size: BovexaTheme.TypeScale.body, weight: .medium))
                        .foregroundStyle(BovexaTheme.Colors.ink)
                        .lineLimit(1)
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .disabled(disabled)

            if let starred, let onStar {
                Button(action: onStar) {
                    Image(systemName: starred ? "star.fill" : "star")
                        .foregroundStyle(starred ? BovexaTheme.Colors.categoryAmber : BovexaTheme.Colors.muted)
                }
                .buttonStyle(.plain)
                .disabled(disabled)
            }
        }
        .padding(.vertical, BovexaTheme.Space.xs)
    }
}
