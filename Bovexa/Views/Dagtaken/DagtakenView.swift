import SwiftUI

/// Dagtaken-tab: composer + "Mijn dagtaken" (plak 3). Archief en de team-sectie
/// komen in plak 4 op ditzelfde scherm.
struct DagtakenView: View {
    @EnvironmentObject private var authStore: AuthStore
    @StateObject private var viewModel = DagtakenViewModel()
    @State private var collapsedIds: Set<String> = []

    private var currentUser: AgendaUser? {
        if case .loggedIn(let user) = authStore.phase { return user }
        return nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                if let user = currentUser {
                    content(for: user)
                } else {
                    ProgressView().tint(BovexaTheme.Colors.teal)
                }
            }
            .navigationTitle("Dagtaken")
            .navigationBarTitleDisplayMode(.large)
        }
        .alert("Mislukt", isPresented: $viewModel.createFailedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Kon de dagtaak niet opslaan.")
        }
        .task {
            await viewModel.loadOrgInfo(token: authStore.token ?? "")
        }
    }

    private func content(for user: AgendaUser) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BovexaTheme.Space.lg) {
                composer(for: user)
                mijnDagtakenSection
            }
            .padding(BovexaTheme.Space.xl)
            .padding(.bottom, BovexaTheme.Space.tabBarClearance)
        }
    }

    private func composer(for user: AgendaUser) -> some View {
        GlassCard(emphasis: .hero) {
            VStack(alignment: .leading, spacing: BovexaTheme.Space.md) {
                HStack {
                    Text(viewModel.isEditing ? "Dagtaak bewerken" : "Nieuwe dagtaak")
                        .font(BovexaTheme.TypeStyle.caption.weight(.bold))
                        .foregroundStyle(BovexaTheme.Colors.accent)
                        .textCase(.uppercase)
                        .tracking(0.3)

                    Spacer()

                    if viewModel.isEditing {
                        Button("Annuleren") {
                            Haptics.selection()
                            viewModel.cancelEdit()
                        }
                        .font(BovexaTheme.TypeStyle.subheadline.weight(.bold))
                        .foregroundStyle(BovexaTheme.Colors.accent)
                    }
                }

                TextField("Titel op de eerste regel\nExtra tekst eronder…", text: $viewModel.draft, axis: .vertical)
                    .font(BovexaTheme.TypeStyle.body)
                    .foregroundStyle(BovexaTheme.Colors.ink)
                    .lineLimit(4...8)
                    .padding(BovexaTheme.Space.sm)
                    .background(BovexaTheme.Colors.glassSoft, in: RoundedRectangle(cornerRadius: BovexaTheme.Radius.sm, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: BovexaTheme.Radius.sm, style: .continuous).stroke(BovexaTheme.Colors.edge, lineWidth: 1))

                if user.defaultOrg != nil, !viewModel.isEditing {
                    VisibilityPickerView(
                        value: viewModel.visibility.rawValue,
                        companyName: viewModel.orgName ?? "Bedrijf"
                    ) { value in
                        viewModel.visibility = TaskVisibility(rawValue: value) ?? .private
                    }
                }

                Button {
                    Haptics.selection()
                    Task { await viewModel.submit(userId: user.id, org: user.defaultOrg, token: authStore.token ?? "") }
                } label: {
                    if viewModel.busy {
                        ProgressView().tint(BovexaTheme.Colors.white)
                    } else {
                        Label(viewModel.isEditing ? "Opslaan" : "Toevoegen", systemImage: viewModel.isEditing ? "checkmark" : "plus")
                    }
                }
                .buttonStyle(.glassProminentBrand)
                .disabled(!viewModel.canSubmit)
            }
        }
    }

    private var mijnDagtakenSection: some View {
        VStack(alignment: .leading, spacing: BovexaTheme.Space.sm) {
            HStack {
                Text("Mijn dagtaken")
                    .font(BovexaTheme.TypeStyle.headline)
                    .foregroundStyle(BovexaTheme.Colors.ink)

                Spacer()

                Text("\(viewModel.openNotes.count) \(viewModel.openNotes.count == 1 ? "dagtaak" : "dagtaken")")
                    .font(BovexaTheme.TypeStyle.footnote)
                    .foregroundStyle(BovexaTheme.Colors.inkSoft)
            }

            if viewModel.openNotes.isEmpty {
                GlassCard(emphasis: .quiet) {
                    EmptyStateView(systemImage: "checklist", text: "Nog geen dagtaken")
                }
            } else {
                VStack(spacing: BovexaTheme.Space.sm) {
                    ForEach(viewModel.openNotes) { note in
                        PlanningRowView(
                            note: note,
                            isEditing: note.id == viewModel.editingId,
                            isExpanded: !collapsedIds.contains(note.id),
                            onToggleExpand: { toggleExpand(note.id) },
                            onEdit: { viewModel.startEdit(note) },
                            onArchive: { viewModel.archive(note.id) }
                        )
                    }
                }
            }
        }
    }

    private func toggleExpand(_ id: String) {
        if collapsedIds.contains(id) {
            collapsedIds.remove(id)
        } else {
            collapsedIds.insert(id)
        }
    }
}

#Preview {
    DagtakenView().environmentObject(AuthStore())
}
