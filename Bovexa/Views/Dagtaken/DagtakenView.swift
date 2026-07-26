import SwiftUI

/// Dagtaken-tab: composer, "Mijn dagtaken", archief en de team-sectie.
struct DagtakenView: View {
    @FocusState private var draftFocused: Bool
    @EnvironmentObject private var authStore: AuthStore
    @StateObject private var viewModel = DagtakenViewModel()
    @State private var collapsedIds: Set<String> = []
    @State private var archiveOpen = false
    @State private var teamTaskPendingDelete: AgendaTask?

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
                    ProgressView().tint(BovexaTheme.Colors.blue)
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
        .alert("Mislukt", isPresented: $viewModel.deleteTeamTaskFailedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Kon de team-dagtaak niet wissen.")
        }
        .alert(
            "Team-dagtaak wissen",
            isPresented: Binding(get: { teamTaskPendingDelete != nil }, set: { if !$0 { teamTaskPendingDelete = nil } })
        ) {
            Button("Annuleren", role: .cancel) { teamTaskPendingDelete = nil }
            Button("Wissen", role: .destructive) {
                confirmDeleteTeamTask()
            }
        } message: {
            Text("\"\(teamTaskPendingDelete?.title ?? "")\" verdwijnt voor het hele team.")
        }
        .task {
            await refresh()
        }
        .onAppear {
            Task { await refresh() }
        }
    }

    /// Herlaadt bij elke terugkeer naar dit scherm — er is geen realtime-abonnement
    /// (RN gebruikt hiervoor useFocusEffect; `.onAppear` is de SwiftUI-tegenhanger).
    private func refresh() async {
        guard let user = currentUser else { return }
        await viewModel.load(userId: user.id, org: user.defaultOrg, token: authStore.token ?? "")
    }

    private func confirmDeleteTeamTask() {
        guard let task = teamTaskPendingDelete, let user = currentUser else { return }
        teamTaskPendingDelete = nil
        Task { await viewModel.deleteTeamTask(task, userId: user.id, token: authStore.token ?? "") }
    }

    private func content(for user: AgendaUser) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BovexaTheme.Space.lg) {
                composer(for: user)
                mijnDagtakenSection
                archiefSection
                teamSection(for: user)
            }
            .padding(BovexaTheme.Space.xl)
            .padding(.bottom, BovexaTheme.Space.tabBarClearance)
        }
        // Naar beneden vegen sluit het toetsenbord; anders bleef het staan
        // over de knoppen heen.
        .scrollDismissesKeyboard(.interactively)
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
                    .keyboardDone(focused: $draftFocused)
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
                            onToggleDone: { viewModel.toggleNote(note.id) },
                            onEdit: { viewModel.startEdit(note) },
                            onArchive: { viewModel.archive(note.id) }
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var archiefSection: some View {
        if !viewModel.archivedNotes.isEmpty {
            VStack(alignment: .leading, spacing: BovexaTheme.Space.sm) {
                Button {
                    Haptics.selection()
                    withAnimation(.snappy) { archiveOpen.toggle() }
                } label: {
                    HStack {
                        HStack(spacing: BovexaTheme.Space.xs) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(BovexaTheme.Colors.muted)
                                .rotationEffect(.degrees(archiveOpen ? 90 : 0))
                            Text("Archief")
                                .font(BovexaTheme.TypeStyle.headline)
                                .foregroundStyle(BovexaTheme.Colors.ink)
                        }

                        Spacer()

                        Text("\(viewModel.archivedNotes.count) \(viewModel.archivedNotes.count == 1 ? "dagtaak" : "dagtaken")")
                            .font(BovexaTheme.TypeStyle.footnote)
                            .foregroundStyle(BovexaTheme.Colors.inkSoft)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if archiveOpen {
                    VStack(spacing: BovexaTheme.Space.sm) {
                        ForEach(viewModel.archivedNotes) { note in
                            PlanningRowView(
                                note: note,
                                isEditing: note.id == viewModel.editingId,
                                isExpanded: !collapsedIds.contains(note.id),
                                onToggleExpand: { toggleExpand(note.id) },
                                onToggleDone: { viewModel.toggleNote(note.id) },
                                onEdit: { viewModel.startEdit(note) },
                                onRestore: { viewModel.restore(note.id) },
                                onDelete: { viewModel.requestDeleteLocalNote(note.id) },
                                deleteLabel: viewModel.confirmDeleteId == note.id ? "Nog eens tikken" : "Wissen"
                            )
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func teamSection(for user: AgendaUser) -> some View {
        if user.defaultOrg != nil {
            VStack(alignment: .leading, spacing: BovexaTheme.Space.sm) {
                HStack {
                    Text("Dagtaken\(viewModel.orgName.map { " — \($0)" } ?? "")")
                        .font(BovexaTheme.TypeStyle.headline)
                        .foregroundStyle(BovexaTheme.Colors.ink)

                    Spacer()

                    Text("\(viewModel.teamTasks.count) \(viewModel.teamTasks.count == 1 ? "dagtaak" : "dagtaken")")
                        .font(BovexaTheme.TypeStyle.footnote)
                        .foregroundStyle(BovexaTheme.Colors.inkSoft)
                }

                if viewModel.teamTasks.isEmpty {
                    Text("Nog geen gedeelde dagtaken. Kies “\(viewModel.orgName ?? "Bedrijf")” bij het toevoegen.")
                        .font(BovexaTheme.TypeStyle.footnote)
                        .foregroundStyle(BovexaTheme.Colors.inkSoft)
                } else {
                    VStack(spacing: BovexaTheme.Space.sm) {
                        ForEach(viewModel.teamTasks) { task in
                            TeamTaskRowView(
                                task: task,
                                isMine: task.owner == user.id,
                                ownerLabel: task.owner == user.id ? "Jij" : (viewModel.memberColors.firstName(for: task.owner) ?? "Collega"),
                                onToggle: { Task { await viewModel.toggleTeamTask(task, userId: user.id, token: authStore.token ?? "") } },
                                onDelete: { teamTaskPendingDelete = task }
                            )
                        }
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
