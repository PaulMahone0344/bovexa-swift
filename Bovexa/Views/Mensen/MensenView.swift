import SwiftUI

/// "Mensen": privécontacten van de gebruiker en collega's uit het bedrijf onder
/// elkaar (m8). Privécontact aantikken opent wijzigen/verwijderen; collega aantikken
/// opent zijn overzicht (gewerkte en geplande dagen, afwezigheid). Beheren doe je
/// niet hier maar bij Bedrijf (valkuil B).
struct MensenView: View {
    @StateObject private var viewModel: MensenViewModel
    @Environment(\.dismiss) private var dismiss
    /// Vriendenkoppelingen tussen accounts. Stond klaar sinds 26 aug en staat
    /// sinds 7 sep in de navigatie: de routes /api/agenda/friends/* bestaan nu.
    @State private var showVrienden = false
    /// Waar een nieuw contact bij hoort. Twee losse knoppen — één bij Privé, één
    /// bij het bedrijf — in plaats van één knop met een keuze in het formulier.
    private enum ToevoegenDoel: Identifiable {
        case prive
        case bedrijf(id: String, naam: String)

        var id: String {
            switch self {
            case .prive: return "prive"
            case .bedrijf(let id, _): return "org-\(id)"
            }
        }
    }

    @State private var toevoegenDoel: ToevoegenDoel?
    @State private var editingContact: AgendaContact?
    /// De collega wiens overzicht openstaat.
    @State private var bekekenMember: CompanyMember?

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
                        if viewModel.loadFailed {
                            LoadFailedNote(surface: .background)
                        }

                        if showSearch { searchField }

                        privateSection

                        koppelingenRij

                        // Zonder bedrijf hoort hier niets te staan: een nieuwe
                        // gebruiker zonder koppeling zag een kop "COLLEGA'S" met
                        // "Geen collega gevonden" eronder, terwijl er voor hem
                        // helemaal geen bedrijf is om mensen bij te zetten.
                        if !viewModel.orgId.isEmpty {
                            companySection
                        }
                    }
                    .padding(BovexaTheme.Space.xl)
                    .padding(.bottom, BovexaTheme.Space.tabBarClearance)
                }
            }
            .navigationTitle("Mensen")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                SheetCloseButton { dismiss() }
            }
        }
        .task { await viewModel.load(userId: userId, token: token) }
        // De fout wordt in de sheet zelf getoond (PersoonFormView.errorText): een
        // alert op dit scherm werd niet gepresenteerd zolang de sheet openstond.
        .sheet(item: $toevoegenDoel, onDismiss: { viewModel.clearError() }) { doel in
            let org: String = {
                if case .bedrijf(let id, _) = doel { return id }
                return ""
            }()
            let titel: String = {
                if case .bedrijf(_, let naam) = doel { return naam }
                return "Privé"
            }()
            PersoonFormView(
                mode: .add,
                doelNaam: titel,
                onSave: { naam, telefoon, notitie in
                    await viewModel.addContact(userId: userId, naam: naam, telefoon: telefoon, notitie: notitie, org: org, token: token)
                },
                errorText: viewModel.errorMessage
            )
        }
        .sheet(item: $bekekenMember) { member in
            MedewerkerDetailView(
                member: member,
                userId: userId,
                orgId: viewModel.orgId.isEmpty ? nil : viewModel.orgId,
                token: token
            )
        }
        .sheet(item: $editingContact, onDismiss: { viewModel.clearError() }) { contact in
            PersoonFormView(
                mode: .edit(contact),
                onSave: { naam, telefoon, notitie in
                    await viewModel.updateContact(id: contact.id, naam: naam, telefoon: telefoon, notitie: notitie, token: token)
                },
                onDelete: {
                    await viewModel.deleteContact(id: contact.id, token: token)
                },
                errorText: viewModel.errorMessage,
                inzetBron: .init(
                    userId: userId,
                    orgId: viewModel.orgId.isEmpty ? nil : viewModel.orgId,
                    token: token
                )
            )
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

    /// Eén rij naar het vriendenscherm: wie mag er in jouw agenda prikken.
    private var koppelingenRij: some View {
        Button {
            Haptics.selection()
            showVrienden = true
        } label: {
            HStack(spacing: BovexaTheme.Space.sm) {
                Image(systemName: "link")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(BovexaTheme.Colors.accent)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Gekoppelde accounts")
                        .font(BovexaTheme.TypeStyle.subheadline.weight(.bold))
                        .foregroundStyle(BovexaTheme.Colors.ink)
                    Text("Verzoeken sturen en beantwoorden")
                        .font(BovexaTheme.TypeStyle.caption)
                        .foregroundStyle(BovexaTheme.Colors.muted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(BovexaTheme.Colors.muted)
            }
            .padding(.horizontal, BovexaTheme.Space.md)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .background(BovexaTheme.Colors.glass)
            .overlay(
                RoundedRectangle(cornerRadius: BovexaTheme.Radius.md, style: .continuous)
                    .strokeBorder(BovexaTheme.Colors.edge, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: BovexaTheme.Radius.md, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showVrienden) {
            VriendenView(token: token)
        }
    }

    private var privateSection: some View {
        VStack(alignment: .leading, spacing: BovexaTheme.Space.sm) {
            sectionHeader("PRIVÉ", knopLabel: "Privépersoon toevoegen") {
                toevoegenDoel = .prive
            }

            if viewModel.loading && viewModel.contacts.isEmpty {
                ProgressView().tint(BovexaTheme.Colors.accent)
            } else if viewModel.visiblePrivateContacts.isEmpty {
                EmptyStateView(systemImage: "person.crop.circle.badge.plus", text: "Nog geen privécontacten. Tik op + hierboven.", surface: .background)
            } else {
                GlassCard(padding: BovexaTheme.Space.xs) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(viewModel.visiblePrivateContacts.enumerated()), id: \.element.id) { index, contact in
                            contactRow(contact, first: index == 0)
                        }
                    }
                }
            }
        }
    }

    /// Kop van een sectie met een eigen plusknop erachter: welke knop je aantikt
    /// bepaalt waar de persoon terechtkomt.
    private func sectionHeader(_ titel: String, knopLabel: String, action: @escaping () -> Void) -> some View {
        HStack {
            Text(titel)
                .font(BovexaTheme.TypeStyle.caption.weight(.bold))
                .foregroundStyle(BovexaTheme.Colors.accent)
            Spacer()
            Button {
                Haptics.selection()
                action()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(BovexaTheme.Colors.accent)
                    .frame(width: 32, height: 32)
                    .background(BovexaTheme.Colors.glass)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(BovexaTheme.Colors.edge, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(knopLabel)
        }
    }

    private var companySection: some View {
        VStack(alignment: .leading, spacing: BovexaTheme.Space.sm) {
            // Geen plusknop meer: onder het bedrijf staat alleen wie een account
            // heeft, en dat regel je met een uitnodiging (Bedrijf > Teambeheer),
            // niet door hier een naam in te typen.
            Text(viewModel.orgName.isEmpty ? "COLLEGA'S" : viewModel.orgName.uppercased())
                .font(BovexaTheme.TypeStyle.caption.weight(.bold))
                .foregroundStyle(BovexaTheme.Colors.accent)

            if viewModel.visibleMembers.isEmpty {
                EmptyStateView(systemImage: "person.2", text: "Geen collega gevonden.", surface: .background)
            } else {
                GlassCard(padding: BovexaTheme.Space.xs) {
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

    /// Aantikken opent het overzicht van die collega: zijn gegevens, hoeveel dagen
    /// hij heeft gewerkt en gepland staat, en wanneer hij afwezig was. Alleen-lezen
    /// (valkuil B) — rol, rechten en verwijderen blijven bij Bedrijf > Teambeheer.
    private func memberRow(_ member: CompanyMember, first: Bool) -> some View {
        Button {
            Haptics.selection()
            bekekenMember = member
        } label: {
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
