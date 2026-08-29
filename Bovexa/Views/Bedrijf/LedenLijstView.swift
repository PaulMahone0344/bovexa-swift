import SwiftUI

/// Ledenlijst op de Bedrijf-tab: zoekbalk vanaf 6 leden, avatar met persoonskleur-
/// ring, "· eigenaar", "Uitgenodigd", rol-chip, ster = lokale favoriet (valkuil H).
/// Rol/rechten/verwijderen per lid komt in plak 4.
struct LedenLijstView: View {
    @ObservedObject var viewModel: BedrijfViewModel
    let currentUserId: String
    /// Alleen admins mogen rol/rechten/verwijderen beheren (valkuil D).
    let canManage: Bool
    let token: String
    @State private var pendingRemove: CompanyMember?

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
                        VStack(alignment: .leading, spacing: 0) {
                            row(for: member, first: index == 0)
                            if viewModel.expandedMemberId == member.id {
                                expandedRow(for: member)
                            }
                        }
                    }
                }
            }
        }
        .alert("Mislukt", isPresented: Binding(
            get: { viewModel.memberActionErrorMessage != nil },
            set: { if !$0 { viewModel.memberActionErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.memberActionErrorMessage ?? "")
        }
        .alert(
            "Lid verwijderen?",
            isPresented: Binding(get: { pendingRemove != nil }, set: { if !$0 { pendingRemove = nil } })
        ) {
            Button("Annuleren", role: .cancel) { pendingRemove = nil }
            Button("Verwijderen", role: .destructive) { confirmRemove() }
        } message: {
            Text("\(pendingRemove?.displayName ?? "Dit lid") verliest toegang tot dit bedrijf.")
        }
    }

    private func confirmRemove() {
        guard let member = pendingRemove else { return }
        pendingRemove = nil
        Task { await viewModel.removeMember(member, actingUserId: currentUserId, token: token) }
    }

    private var searchField: some View {
        HStack(spacing: BovexaTheme.Space.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(BovexaTheme.Colors.muted)
            TextField("Zoek collega", text: $viewModel.memberQuery)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .font(BovexaTheme.TypeStyle.body)
        }
        .padding(.horizontal, BovexaTheme.Space.md)
        // Als duidelijke pill (keuze Ibrahim 29 aug): het veld zonk weg in het
        // glas van de lijst en las als kale tekst in plaats van als invoerveld.
        .frame(minHeight: 44)
        .background(BovexaTheme.Colors.white.opacity(0.55), in: Capsule())
        .overlay(Capsule().stroke(BovexaTheme.Colors.edge, lineWidth: 1))
    }

    private func rowManageable(_ member: CompanyMember) -> Bool {
        canManage && member.canBeManaged(by: currentUserId)
    }

    @ViewBuilder
    private func row(for member: CompanyMember, first: Bool) -> some View {
        let manageable = rowManageable(member)

        // Alleen een beheerbare rij wordt een Button: een niet-beheerbare rij heeft
        // geen actie en hoort dus ook geen knop-rol te krijgen. De ster blijft in
        // beide gevallen zijn eigen Button (valkuil C/D) en dimt niet mee.
        if manageable {
            Button {
                Haptics.selection()
                viewModel.toggleExpanded(member.id)
            } label: {
                rowContent(for: member, first: first, manageable: true)
            }
            .buttonStyle(.plain)
            .accessibilityValue(viewModel.expandedMemberId == member.id ? "uitgeklapt" : "ingeklapt")
        } else {
            rowContent(for: member, first: first, manageable: false)
        }
    }

    private func rowContent(for member: CompanyMember, first: Bool, manageable: Bool) -> some View {
        let expanded = viewModel.expandedMemberId == member.id

        return HStack(spacing: BovexaTheme.Space.sm) {
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
                    .minTapTarget()
            }
            .buttonStyle(.plain)
            .accessibilityLabel(viewModel.isFavorite(member.userId) ? "Favoriet verwijderen" : "Als favoriet markeren")

            if manageable {
                if viewModel.busyMemberId == member.id {
                    ProgressView().tint(BovexaTheme.Colors.muted)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(expanded ? BovexaTheme.Colors.accent : BovexaTheme.Colors.muted)
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                }
            }
        }
        // Padding vóór contentShape: andersom bleef de 10pt rand rondom de rij dood.
        .padding(.horizontal, BovexaTheme.Space.sm)
        .padding(.vertical, BovexaTheme.Space.sm)
        .contentShape(Rectangle())
        .overlay(alignment: .top) {
            if !first {
                Rectangle().fill(BovexaTheme.Colors.edgeSoft).frame(height: 1)
            }
        }
    }

    private func expandedRow(for member: CompanyMember) -> some View {
        VStack(alignment: .leading, spacing: BovexaTheme.Space.sm) {
            HStack(spacing: BovexaTheme.Space.xs) {
                ForEach(SelectableCompanyRole.allCases, id: \.self) { option in
                    // Opmaak ín het label (M11 patroon A): stond de padding en de
                    // capsule op de Button, dan raakte alleen de 12pt tekst en gaf
                    // de capsule geen ingedrukt-feedback.
                    Button {
                        Haptics.selection()
                        Task { await viewModel.changeRole(member, to: option.role, actingUserId: currentUserId, token: token) }
                    } label: {
                        Text(option.label)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(member.role == option.role ? BovexaTheme.Colors.accent : BovexaTheme.Colors.inkSoft)
                            .padding(.horizontal, BovexaTheme.Space.sm)
                            .frame(minHeight: 36)
                            .background(
                                Capsule().fill(member.role == option.role ? BovexaTheme.Colors.accent.opacity(0.14) : BovexaTheme.Colors.glass)
                            )
                            .overlay(Capsule().stroke(BovexaTheme.Colors.edge, lineWidth: member.role == option.role ? 0 : 1))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(member.role == option.role ? .isSelected : [])
                }
            }

            VStack(alignment: .leading, spacing: BovexaTheme.Space.xs) {
                ForEach(CompanyPermission.allCases, id: \.self) { permission in
                    let on = member.value(forPermissionKey: permission.rawValue)
                    Button {
                        Haptics.selection()
                        Task { await viewModel.togglePermission(member, key: permission, actingUserId: currentUserId, token: token) }
                    } label: {
                        HStack(spacing: BovexaTheme.Space.sm) {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(on ? BovexaTheme.Colors.blueDeep : BovexaTheme.Colors.glass)
                                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(on ? BovexaTheme.Colors.blueDeep : BovexaTheme.Colors.edge, lineWidth: 1.5))
                                .frame(width: 20, height: 20)
                                .overlay {
                                    if on {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(BovexaTheme.Colors.white)
                                    }
                                }
                            Text(permission.label)
                                .font(BovexaTheme.TypeStyle.footnote.weight(.medium))
                                .foregroundStyle(BovexaTheme.Colors.inkSoft)
                            Spacer()
                        }
                        // Vijf rijen van 20pt boven elkaar: één mis-tik zette het
                        // verkeerde recht om, inclusief netwerkcall.
                        .frame(minHeight: 36)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityValue(on ? "aan" : "uit")
                }
            }

            Button(role: .destructive) {
                Haptics.warning()
                pendingRemove = member
            } label: {
                Text("Verwijderen")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(BovexaTheme.Colors.danger)
                    .padding(.horizontal, BovexaTheme.Space.xs)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, BovexaTheme.Space.sm)
        .padding(.bottom, BovexaTheme.Space.sm)
        // Zolang er een actie loopt doet de viewmodel toch niets (guard) — dan
        // moeten de knoppen dat ook laten zien in plaats van dood aan te voelen.
        .disabled(viewModel.busyMemberId != nil)
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
        case .admin: label = "Beheerder"
        }
        return Text(label)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(BovexaTheme.Colors.accent)
            .padding(.horizontal, BovexaTheme.Space.xs)
            .padding(.vertical, 3)
            .background(BovexaTheme.Colors.accent.opacity(0.12), in: Capsule())
    }
}
