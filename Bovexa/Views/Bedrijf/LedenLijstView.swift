import SwiftUI

/// Ledenlijst op de Bedrijf-tab: zoekbalk vanaf 6 leden, avatar met persoonskleur-
/// ring, "· eigenaar", "Uitgenodigd", rol-chip, ster = lokale favoriet (valkuil H).
/// Rol/rechten/verwijderen per lid komt in plak 4.
struct LedenLijstView: View {
    @ObservedObject var viewModel: BedrijfViewModel
    let currentUserId: String

    private static let searchFrom = 6

    var body: some View {
        GlassCard(padding: BovexaTheme.Space.xs) {
            VStack(alignment: .leading, spacing: 0) {
                if viewModel.members.count >= Self.searchFrom {
                    searchField
                }

                if viewModel.visibleMembers.isEmpty {
                    Text("Geen collega gevonden.")
                        .font(BovexaTheme.TypeStyle.subheadline)
                        .foregroundStyle(BovexaTheme.Colors.muted)
                        .padding(BovexaTheme.Space.md)
                } else {
                    ForEach(Array(viewModel.visibleMembers.enumerated()), id: \.element.id) { index, member in
                        row(for: member, first: index == 0)
                    }
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: BovexaTheme.Space.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(BovexaTheme.Colors.muted)
            TextField("Zoek collega", text: $viewModel.memberQuery)
                .autocorrectionDisabled()
                .font(BovexaTheme.TypeStyle.body)
        }
        .padding(.horizontal, BovexaTheme.Space.sm)
        .padding(.vertical, BovexaTheme.Space.xs)
    }

    private func row(for member: CompanyMember, first: Bool) -> some View {
        HStack(spacing: BovexaTheme.Space.sm) {
            avatar(for: member)

            VStack(alignment: .leading, spacing: 2) {
                Text(nameLabel(for: member))
                    .font(BovexaTheme.TypeStyle.subheadline.weight(.bold))
                    .foregroundStyle(BovexaTheme.Colors.inkSoft)
                    .lineLimit(1)
                if member.isInvited {
                    Text("Uitgenodigd")
                        .font(BovexaTheme.TypeStyle.caption)
                        .foregroundStyle(BovexaTheme.Colors.muted)
                }
            }

            Spacer()

            roleChip(for: member.role)

            Button {
                Haptics.selection()
                viewModel.toggleFavorite(member.userId, currentUserId: currentUserId)
            } label: {
                Image(systemName: viewModel.isFavorite(member.userId) ? "star.fill" : "star")
                    .foregroundStyle(viewModel.isFavorite(member.userId) ? BovexaTheme.Colors.categoryAmber : BovexaTheme.Colors.muted)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, BovexaTheme.Space.sm)
        .padding(.vertical, BovexaTheme.Space.sm)
        .overlay(alignment: .top) {
            if !first {
                Rectangle().fill(BovexaTheme.Colors.edgeSoft).frame(height: 1)
            }
        }
    }

    private func nameLabel(for member: CompanyMember) -> String {
        let base = viewModel.memberColors.firstName(for: member.userId) ?? member.displayName
        return member.isOwner ? "\(base) · eigenaar" : base
    }

    private func avatar(for member: CompanyMember) -> some View {
        let color = viewModel.memberColors.color(for: member.userId)
        let initial = nameLabel(for: member).first.map { String($0).uppercased() }
        return Circle()
            .fill(color.opacity(0.18))
            .frame(width: 34, height: 34)
            .overlay(Circle().stroke(color, lineWidth: 2))
            .overlay {
                if let initial {
                    Text(initial)
                        .font(.system(.footnote, design: .rounded, weight: .bold))
                        .foregroundStyle(color)
                }
            }
    }

    private func roleChip(for role: CompanyRole) -> some View {
        let label: String
        switch role {
        case .member: label = "Medewerker"
        case .manager: label = "Manager"
        case .admin: label = "Admin"
        }
        return Text(label)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(BovexaTheme.Colors.accent)
            .padding(.horizontal, BovexaTheme.Space.xs)
            .padding(.vertical, 3)
            .background(BovexaTheme.Colors.accent.opacity(0.12), in: Capsule())
    }
}
