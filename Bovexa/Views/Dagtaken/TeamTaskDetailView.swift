import SwiftUI

/// Detail van één team-dagtaak: titel, notitie, wie hem heeft gezet en wanneer,
/// wanneer hij is afgevinkt, plus afvinken en wissen. De taak komt uit het
/// viewmodel en niet uit een kopie, zodat afvinken hier meteen ook in de lijst
/// eronder klopt.
struct TeamTaskDetailView: View {
    @ObservedObject var viewModel: DagtakenViewModel
    let taskId: String
    let currentUserId: String
    let token: String
    @Environment(\.dismiss) private var dismiss

    @State private var showDeleteConfirm = false
    @State private var isDeleting = false

    private var task: AgendaTask? {
        viewModel.teamTasks.first { $0.id == taskId }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                if let task {
                    ScrollView {
                        VStack(alignment: .leading, spacing: BovexaTheme.Space.lg) {
                            titleCard(task)
                            metaCard(task)
                            actions(task)
                        }
                        .padding(BovexaTheme.Space.xl)
                    }
                } else {
                    // Kan alleen als de taak intussen elders is gewist; dan sluit het
                    // scherm zichzelf in plaats van een lege kaart te tonen.
                    Color.clear.onAppear { dismiss() }
                }
            }
            .navigationTitle("Dagtaak")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Sluiten") { dismiss() }
                }
            }
            .alert("Dagtaak wissen", isPresented: $showDeleteConfirm) {
                Button("Annuleren", role: .cancel) {}
                Button("Wissen", role: .destructive) {
                    Task {
                        guard let task else { return }
                        isDeleting = true
                        await viewModel.deleteTeamTask(task, userId: currentUserId, token: token)
                        isDeleting = false
                        if !viewModel.deleteTeamTaskFailedAlert { dismiss() }
                    }
                }
            } message: {
                Text("\"\(task?.title ?? "")\" wordt definitief gewist.")
            }
            // Deze alert hing op DagtakenView, ónder deze sheet: het wissen mislukte
            // dan zichtbaar nergens en de melding kwam pas nadat je zelf sloot.
            .alert("Mislukt", isPresented: $viewModel.deleteTeamTaskFailedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Kon de team-dagtaak niet wissen.")
            }
        }
    }

    private func titleCard(_ task: AgendaTask) -> some View {
        GlassCard(emphasis: .hero) {
            VStack(alignment: .leading, spacing: BovexaTheme.Space.sm) {
                Text(task.title)
                    .font(BovexaTheme.TypeStyle.title3)
                    .foregroundStyle(task.status == .klaar ? BovexaTheme.Colors.muted : BovexaTheme.Colors.ink)
                    .strikethrough(task.status == .klaar)

                if let notes = task.notes, !notes.isEmpty {
                    Text(notes)
                        .font(BovexaTheme.TypeStyle.body)
                        .foregroundStyle(BovexaTheme.Colors.inkSoft)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func metaCard(_ task: AgendaTask) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BovexaTheme.Space.sm) {
                row(icon: "person", text: TaskAuthorFormatting.label(owner: ownerName(task), created: task.created))

                if let completedAt = task.completedAt {
                    row(icon: "checkmark.circle", text: TaskCompletionFormatting.label(completedAt: completedAt))
                } else {
                    row(icon: "circle", text: "Nog niet afgevinkt")
                }

                if task.visibility == .company {
                    row(icon: "building.2", text: viewModel.orgName ?? "Bedrijf")
                } else {
                    row(icon: "lock", text: "Privé")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func actions(_ task: AgendaTask) -> some View {
        VStack(spacing: BovexaTheme.Space.sm) {
            if TaskPermissions.canToggle(task, userId: currentUserId) {
                Button {
                    Haptics.selection()
                    Task { await viewModel.toggleTeamTask(task, userId: currentUserId, token: token) }
                } label: {
                    Label(
                        task.status == .klaar ? "Toch nog niet klaar" : "Afvinken",
                        systemImage: task.status == .klaar ? "arrow.uturn.backward" : "checkmark"
                    )
                    .frame(maxWidth: .infinity, minHeight: 42)
                }
                .buttonStyle(.glassProminentBrand)
            }

            if TaskPermissions.canDelete(task, userId: currentUserId) {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Wissen", systemImage: "trash")
                        .frame(maxWidth: .infinity, minHeight: 42)
                }
                // `.tint` deed niets: GlassSecondaryButtonStyle zette de accentkleur
                // hard op het label. De danger-variant regelt het nu in de stijl.
                .buttonStyle(.glassSecondaryDanger)
                .disabled(isDeleting)
            } else {
                Text("Alleen \(ownerName(task)) kan deze dagtaak wissen.")
                    .font(BovexaTheme.TypeStyle.caption)
                    .foregroundStyle(BovexaTheme.Colors.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func row(icon: String, text: String) -> some View {
        HStack(spacing: BovexaTheme.Space.sm) {
            Image(systemName: icon)
                .foregroundStyle(BovexaTheme.Colors.muted)
                .frame(width: 20)
            Text(text)
                .font(BovexaTheme.TypeStyle.subheadline)
                .foregroundStyle(BovexaTheme.Colors.ink)
        }
    }

    private func ownerName(_ task: AgendaTask) -> String {
        task.owner == currentUserId ? "Jij" : (viewModel.memberColors.firstName(for: task.owner) ?? "Collega")
    }
}
