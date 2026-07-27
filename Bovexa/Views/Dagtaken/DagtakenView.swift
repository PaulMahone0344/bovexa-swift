import SwiftUI

/// Dagtaken-tab: één lijst tegelijk (Mijn of Bedrijf) met een schakelaar erboven,
/// het archief onder de eigen lijst, en de composer achter de +-knop rechtsboven.
/// Vóór 27 juli stonden composer, eigen lijst, archief en bedrijfslijst onder
/// elkaar: de bedrijfstaken lagen dan een half scherm scrollen verderop, ook als je
/// eigen lijst leeg was.
struct DagtakenView: View {
    @FocusState private var draftFocused: Bool
    @EnvironmentObject private var authStore: AuthStore
    @StateObject private var viewModel = DagtakenViewModel()
    @State private var collapsedIds: Set<String> = []
    @State private var archiveOpen = false
    /// Afgevinkte bedrijfstaken staan standaard dicht — anders groeit de lijst met
    /// alles wat al gedaan is en moet je daar dagelijks langs.
    @State private var doneOpen = false
    /// Welke team-dagtaak openstaat. Wissen zit sinds 27 juli in dat detailscherm,
    /// niet meer als rode knop in elke rij.
    @State private var openTeamTask: AgendaTask?
    @State private var scope: DagtakenScope = .mijn
    @State private var showComposer = false

    private let scopePreference = DagtakenScopePreference()

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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Haptics.selection()
                        showComposer = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Nieuwe dagtaak")
                }
            }
        }
        .sheet(isPresented: $showComposer, onDismiss: { viewModel.cancelEdit() }) {
            if let user = currentUser {
                composerSheet(for: user)
            }
        }
        // Bewerken opent dezelfde composer; hij staat niet meer vast bovenaan het
        // scherm, dus zonder dit gebeurde er zichtbaar niets bij "Bewerken".
        .onChange(of: viewModel.isEditing) { _, isEditing in
            if isEditing { showComposer = true }
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
        .sheet(item: $openTeamTask) { task in
            if let user = currentUser {
                TeamTaskDetailView(
                    viewModel: viewModel, taskId: task.id,
                    currentUserId: user.id, token: authStore.token ?? ""
                )
            }
        }
        .task {
            scope = scopePreference.load()
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

    private func content(for user: AgendaUser) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BovexaTheme.Space.lg) {
                if user.defaultOrg != nil {
                    scopeSwitch
                }

                if scope == .bedrijf, user.defaultOrg != nil {
                    teamSection(for: user)
                } else {
                    mijnDagtakenSection
                    archiefSection
                }
            }
            .padding(BovexaTheme.Space.xl)
            .padding(.bottom, BovexaTheme.Space.tabBarClearance)
        }
        // Naar beneden vegen sluit het toetsenbord; anders bleef het staan
        // over de knoppen heen.
        .scrollDismissesKeyboard(.interactively)
    }

    /// Twee pillen met hun aantal erin: welke lijst je ziet, en hoeveel erin staat
    /// zonder erheen te hoeven.
    private var scopeSwitch: some View {
        HStack(spacing: BovexaTheme.Space.sm) {
            ForEach(DagtakenScope.allCases, id: \.self) { option in
                let active = scope == option
                Button {
                    Haptics.selection()
                    withAnimation(.snappy(duration: 0.2)) { scope = option }
                    scopePreference.save(option)
                } label: {
                    HStack(spacing: BovexaTheme.Space.xs) {
                        Text(option == .bedrijf ? (viewModel.orgName ?? option.label) : option.label)
                            .font(BovexaTheme.TypeStyle.subheadline.weight(.bold))
                        Text("\(count(for: option))")
                            .font(BovexaTheme.TypeStyle.caption.weight(.bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(active ? BovexaTheme.Colors.white.opacity(0.25) : BovexaTheme.Colors.glassSoft)
                            .clipShape(Capsule())
                    }
                    .foregroundStyle(active ? BovexaTheme.Colors.white : BovexaTheme.Colors.muted)
                    .padding(.horizontal, BovexaTheme.Space.md)
                    .frame(maxWidth: .infinity, minHeight: 38)
                    .background(active ? BovexaTheme.Colors.blueDeep : BovexaTheme.Colors.glass)
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(active ? BovexaTheme.Colors.blueDeep : BovexaTheme.Colors.edge, lineWidth: 1))
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Het getal in de pil telt wat er nog te doen is, niet hoeveel er ooit is
    /// aangemaakt: een lijst die alleen maar oploopt zegt niets.
    private func count(for scope: DagtakenScope) -> Int {
        scope == .mijn ? viewModel.openNotes.count : TeamTaskGrouping.split(viewModel.teamTasks).open.count
    }

    /// De composer zit sinds 27 juli achter de +-knop: als vaste kaart bovenaan
    /// duwde hij beide lijsten een half scherm naar beneden, terwijl je meestal
    /// komt kijken en niet toevoegen.
    private func composerSheet(for user: AgendaUser) -> some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    composer(for: user)
                        .padding(BovexaTheme.Space.xl)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(viewModel.isEditing ? "Dagtaak bewerken" : "Nieuwe dagtaak")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annuleren") {
                        viewModel.cancelEdit()
                        showComposer = false
                    }
                }
            }
        }
    }

    private func composer(for user: AgendaUser) -> some View {
        GlassCard(emphasis: .hero) {
            VStack(alignment: .leading, spacing: BovexaTheme.Space.md) {
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
                    Task { await submitFromComposer(user: user) }
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
            let groups = TeamTaskGrouping.split(viewModel.teamTasks)

            VStack(alignment: .leading, spacing: BovexaTheme.Space.lg) {
                VStack(alignment: .leading, spacing: BovexaTheme.Space.sm) {
                    HStack {
                        Text("Te doen")
                            .font(BovexaTheme.TypeStyle.headline)
                            .foregroundStyle(BovexaTheme.Colors.ink)

                        Spacer()

                        Text("\(groups.open.count) \(groups.open.count == 1 ? "dagtaak" : "dagtaken")")
                            .font(BovexaTheme.TypeStyle.footnote)
                            .foregroundStyle(BovexaTheme.Colors.inkSoft)
                    }

                    if viewModel.teamTasks.isEmpty {
                        Text("Nog geen gedeelde dagtaken. Kies “\(viewModel.orgName ?? "Bedrijf")” bij het toevoegen.")
                            .font(BovexaTheme.TypeStyle.footnote)
                            .foregroundStyle(BovexaTheme.Colors.inkSoft)
                    } else if groups.open.isEmpty {
                        Text("Alles afgevinkt.")
                            .font(BovexaTheme.TypeStyle.footnote)
                            .foregroundStyle(BovexaTheme.Colors.inkSoft)
                    } else {
                        teamRows(groups.open, user: user)
                    }
                }

                if !groups.done.isEmpty {
                    afgevinktSection(groups.done, user: user)
                }
            }
        }
    }

    /// Afgevinkte bedrijfstaken onder een eigen kop, standaard dicht: ze zakken uit
    /// de weg zodra je ze afvinkt, maar blijven terug te vinden.
    private func afgevinktSection(_ tasks: [AgendaTask], user: AgendaUser) -> some View {
        VStack(alignment: .leading, spacing: BovexaTheme.Space.sm) {
            Button {
                Haptics.selection()
                withAnimation(.snappy) { doneOpen.toggle() }
            } label: {
                HStack {
                    HStack(spacing: BovexaTheme.Space.xs) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(BovexaTheme.Colors.muted)
                            .rotationEffect(.degrees(doneOpen ? 90 : 0))
                        Text("Afgevinkt")
                            .font(BovexaTheme.TypeStyle.headline)
                            .foregroundStyle(BovexaTheme.Colors.ink)
                    }

                    Spacer()

                    Text("\(tasks.count) \(tasks.count == 1 ? "dagtaak" : "dagtaken")")
                        .font(BovexaTheme.TypeStyle.footnote)
                        .foregroundStyle(BovexaTheme.Colors.inkSoft)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if doneOpen {
                teamRows(tasks, user: user)
            }
        }
    }

    private func teamRows(_ tasks: [AgendaTask], user: AgendaUser) -> some View {
        VStack(spacing: BovexaTheme.Space.sm) {
            ForEach(tasks) { task in
                TeamTaskRowView(
                    task: task,
                    canToggle: TaskPermissions.canToggle(task, userId: user.id),
                    ownerLabel: task.owner == user.id ? "Jij" : (viewModel.memberColors.firstName(for: task.owner) ?? "Collega"),
                    onToggle: { Task { await viewModel.toggleTeamTask(task, userId: user.id, token: authStore.token ?? "") } },
                    onOpen: { openTeamTask = task }
                )
            }
        }
    }

    /// Sluit de composer alleen als het opslaan is gelukt — bij een mislukking blijft
    /// de tekst staan, anders ben je hem kwijt en mag je hem opnieuw typen. Een taak
    /// voor het bedrijf zet meteen de bedrijfslijst aan: anders komt hij terecht in
    /// een lijst die je op dat moment niet ziet.
    private func submitFromComposer(user: AgendaUser) async {
        let wasTeamTask = user.defaultOrg != nil && viewModel.visibility != .private && !viewModel.isEditing
        await viewModel.submit(userId: user.id, org: user.defaultOrg, token: authStore.token ?? "")

        guard !viewModel.createFailedAlert, viewModel.draft.isEmpty else { return }
        if wasTeamTask {
            scope = .bedrijf
            scopePreference.save(.bedrijf)
        }
        showComposer = false
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
