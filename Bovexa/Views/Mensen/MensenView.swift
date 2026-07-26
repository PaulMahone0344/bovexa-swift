import SwiftUI

/// "Mensen": privécontacten van de gebruiker en collega's uit het bedrijf onder
/// elkaar (m8). Privécontact aantikken opent wijzigen/verwijderen; collega aantikken
/// doet hier niets (die beheer je bij Bedrijf, valkuil B — geen toewijzing/account).
struct MensenView: View {
    @StateObject private var viewModel: MensenViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showAddContact = false
    @State private var editingContact: AgendaContact?

    private let userId: String
    private let token: String

    init(userId: String, token: String) {
        _viewModel = StateObject(wrappedValue: MensenViewModel())
        self.userId = userId
        self.token = token
    }

    private var showSearch: Bool { viewModel.contacts.count + viewModel.members.count >= 6 }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: BovexaTheme.Space.lg) {
                        if showSearch { searchField }

                        privateSection
                        companySection
                    }
                    .padding(BovexaTheme.Space.xl)
                    .padding(.bottom, BovexaTheme.Space.tabBarClearance)
                }
            }
            .navigationTitle("Mensen")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "chevron.left") }
                        .accessibilityLabel("Sluiten")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Persoon toevoegen") {
                        Haptics.selection()
                        showAddContact = true
                    }
                    .font(BovexaTheme.TypeStyle.subheadline.weight(.semibold))
                }
            }
        }
        .task { await viewModel.load(userId: userId, token: token) }
        .sheet(isPresented: $showAddContact) {
            PersoonFormView(mode: .add) { naam, telefoon, notitie in
                await viewModel.addContact(userId: userId, naam: naam, telefoon: telefoon, notitie: notitie, token: token)
            }
        }
        .sheet(item: $editingContact) { contact in
            PersoonFormView(mode: .edit(contact)) { naam, telefoon, notitie in
                await viewModel.updateContact(id: contact.id, naam: naam, telefoon: telefoon, notitie: notitie, token: token)
            } onDelete: {
                await viewModel.deleteContact(id: contact.id, token: token)
            }
        }
        .alert("Mislukt", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var searchField: some View {
        HStack(spacing: BovexaTheme.Space.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(BovexaTheme.Colors.muted)
            TextField("Zoek in Mensen", text: $viewModel.query)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .font(BovexaTheme.TypeStyle.body)
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

    private var privateSection: some View {
        VStack(alignment: .leading, spacing: BovexaTheme.Space.sm) {
            Text("PRIVÉ")
                .font(BovexaTheme.TypeStyle.caption.weight(.bold))
                .foregroundStyle(BovexaTheme.Colors.accent)

            if viewModel.loading && viewModel.contacts.isEmpty {
                ProgressView().tint(BovexaTheme.Colors.accent)
            } else if viewModel.visibleContacts.isEmpty {
                EmptyStateView(systemImage: "person.crop.circle.badge.plus", text: "Nog geen privécontacten. Tik op \"Persoon toevoegen\".", surface: .background)
            } else {
                GlassCard(padding: BovexaTheme.Space.xs) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(viewModel.visibleContacts.enumerated()), id: \.element.id) { index, contact in
                            contactRow(contact, first: index == 0)
                        }
                    }
                }
            }
        }
    }

    private var companySection: some View {
        VStack(alignment: .leading, spacing: BovexaTheme.Space.sm) {
            Text(viewModel.orgName.isEmpty ? "COLLEGA'S" : viewModel.orgName.uppercased())
                .font(BovexaTheme.TypeStyle.caption.weight(.bold))
                .foregroundStyle(BovexaTheme.Colors.accent)

            if viewModel.visibleMembers.isEmpty {
                EmptyStateView(systemImage: "person.2", text: "Geen collega gevonden.", surface: .background)
            } else {
                GlassCard(padding: BovexaTheme.Space.xs, emphasis: .quiet) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(viewModel.visibleMembers.enumerated()), id: \.element.id) { index, member in
                            memberRow(member, first: index == 0)
                        }
                    }
                }
            }
        }
    }

    private func contactRow(_ contact: AgendaContact, first: Bool) -> some View {
        Button {
            Haptics.selection()
            editingContact = contact
        } label: {
            HStack(spacing: BovexaTheme.Space.sm) {
                initialBadge(contact.naam, color: BovexaTheme.Colors.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text(contact.naam)
                        .font(BovexaTheme.TypeStyle.subheadline.weight(.bold))
                        .foregroundStyle(BovexaTheme.Colors.ink)
                    if !contact.telefoon.isEmpty {
                        Text(contact.telefoon)
                            .font(BovexaTheme.TypeStyle.caption)
                            .foregroundStyle(BovexaTheme.Colors.muted)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(BovexaTheme.Colors.muted)
            }
            .padding(.horizontal, BovexaTheme.Space.sm)
            .padding(.vertical, BovexaTheme.Space.sm)
            .overlay(alignment: .top) {
                if !first {
                    Rectangle().fill(BovexaTheme.Colors.edgeSoft).frame(height: 1)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Collega's zijn hier alleen-lezen (valkuil B) — geen tik-actie, geen chevron.
    private func memberRow(_ member: CompanyMember, first: Bool) -> some View {
        HStack(spacing: BovexaTheme.Space.sm) {
            initialBadge(member.displayName, color: viewModel.memberColors.color(for: member.userId))
            VStack(alignment: .leading, spacing: 2) {
                Text(member.displayName)
                    .font(BovexaTheme.TypeStyle.subheadline.weight(.bold))
                    .foregroundStyle(BovexaTheme.Colors.inkSoft)
                Text(MemberSubtitle.text(for: member, currentUserId: userId))
                    .font(BovexaTheme.TypeStyle.caption)
                    .foregroundStyle(BovexaTheme.Colors.muted)
            }
            Spacer()
        }
        .padding(.horizontal, BovexaTheme.Space.sm)
        .padding(.vertical, BovexaTheme.Space.sm)
        .overlay(alignment: .top) {
            if !first {
                Rectangle().fill(BovexaTheme.Colors.edgeSoft).frame(height: 1)
            }
        }
    }

    private func initialBadge(_ naam: String, color: Color) -> some View {
        Circle()
            .fill(color.opacity(0.18))
            .frame(width: 34, height: 34)
            .overlay(Circle().stroke(color, lineWidth: 2))
            .overlay {
                Text(naam.prefix(1).uppercased())
                    .font(.system(.footnote, design: .rounded, weight: .bold))
                    .foregroundStyle(color)
            }
    }
}

#Preview {
    MensenView(userId: "u1", token: "tok")
}
