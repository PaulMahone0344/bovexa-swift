import SwiftUI

/// Afspraak-detail: titel, categorie-kleur, dag+tijd, locatie, klant-regel, notitie,
/// "Van <voornaam>" bij andermans afspraak, verwijderen (eigenaar), toewijzingen
/// accepteren/weigeren en zichtbaarheid wijzigen (eigenaar + bedrijf). Bewerken komt
/// in een latere plak. Terug-knop komt gratis mee via NavigationStack.
struct EventDetailView: View {
    @StateObject private var viewModel: EventDetailViewModel
    @ObservedObject var memberColors: MemberColors
    @Environment(\.dismiss) private var dismiss

    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var isEditing = false

    private let token: String

    init(event: AgendaEvent, currentUserId: String, currentUserOrgId: String?, token: String, memberColors: MemberColors) {
        _viewModel = StateObject(wrappedValue: EventDetailViewModel(
            event: event, currentUserId: currentUserId, currentUserOrgId: currentUserOrgId, token: token
        ))
        self.memberColors = memberColors
        self.token = token
    }

    private var event: AgendaEvent { viewModel.event }
    private var isColleague: Bool { event.owner != viewModel.currentUserId }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                if isEditing {
                    EventEditorView(
                        event: event, currentUserId: viewModel.currentUserId, token: token, members: memberColors.members,
                        onCancel: { isEditing = false },
                        onSaved: { updated in
                            viewModel.applyEditorSave(updated)
                            isEditing = false
                        }
                    )
                    .padding(BovexaTheme.Space.xl)
                } else {
                    VStack(spacing: BovexaTheme.Space.lg) {
                        detailCard

                        if !event.assignee.isEmpty {
                            assigneesCard
                        }

                        if viewModel.showVisibilityPicker {
                            VisibilityPickerView(value: viewModel.normalizedVisibility, companyName: memberColors.orgName ?? "Bedrijf") { value in
                                Task { await viewModel.changeVisibility(value) }
                            }
                        }
                    }
                    .padding(BovexaTheme.Space.xl)
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isEditing && viewModel.canDelete {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showDeleteConfirm = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(isDeleting)
                }
            }
            if !isEditing && viewModel.canEdit {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isEditing = true
                    } label: {
                        Image(systemName: "pencil")
                    }
                }
            }
        }
        .alert("Afspraak verwijderen", isPresented: $showDeleteConfirm) {
            Button("Annuleren", role: .cancel) {}
            Button("Verwijder", role: .destructive) {
                Task {
                    isDeleting = true
                    if await viewModel.delete() {
                        Haptics.warning()
                        dismiss()
                    }
                    isDeleting = false
                }
            }
        } message: {
            Text("\"\(event.title)\" wordt definitief verwijderd.")
        }
        .alert("Mislukt", isPresented: $viewModel.deleteFailedAlert) {
            Button("Oké", role: .cancel) {}
        } message: {
            Text("Kon de afspraak niet verwijderen.")
        }
        .alert("Mislukt", isPresented: $viewModel.respondFailedAlert) {
            Button("Oké", role: .cancel) {}
        } message: {
            Text("Kon je antwoord niet opslaan.")
        }
        .alert("Mislukt", isPresented: $viewModel.visibilityFailedAlert) {
            Button("Oké", role: .cancel) {}
        } message: {
            Text("Kon de zichtbaarheid niet opslaan.")
        }
    }

    private var detailCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BovexaTheme.Space.md) {
                HStack(spacing: BovexaTheme.Space.sm) {
                    Circle()
                        .fill(EventHelpers.eventColor(event))
                        .frame(width: 12, height: 12)
                    Text(event.title)
                        .font(BovexaTheme.TypeStyle.title2)
                        .foregroundStyle(BovexaTheme.Colors.ink)
                }

                if isColleague, let firstName = memberColors.firstName(for: event.owner) {
                    Text("Van \(firstName)")
                        .font(BovexaTheme.TypeStyle.footnote.weight(.medium))
                        .foregroundStyle(memberColors.color(for: event.owner))
                }

                Divider().overlay(BovexaTheme.Colors.edgeSoft)

                detailRow(icon: "calendar", text: EventHelpers.longDay(event.start))
                detailRow(icon: "clock", text: EventHelpers.detailTimeText(event))

                if let location = event.location, !location.isEmpty {
                    detailRow(icon: "mappin.and.ellipse", text: location)
                }

                if let klant = event.klantNaam, !klant.isEmpty {
                    detailRow(icon: "person", text: klant)
                }

                if let notes = event.notes, !notes.isEmpty {
                    Divider().overlay(BovexaTheme.Colors.edgeSoft)
                    Text(notes)
                        .font(BovexaTheme.TypeStyle.body)
                        .foregroundStyle(BovexaTheme.Colors.inkSoft)
                }
            }
        }
    }

    /// Wie de afspraak uitvoert, los van wie mag meekijken — toegewezenen zien 'm sowieso.
    private var assigneesCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BovexaTheme.Space.md) {
                HStack {
                    Text("TOEGEWEZEN AAN")
                        .font(BovexaTheme.TypeStyle.caption.weight(.bold))
                        .foregroundStyle(BovexaTheme.Colors.accent)
                        .tracking(0.3)
                    Spacer()
                    if viewModel.isAssignedToMe {
                        Text("Aan jou")
                            .font(BovexaTheme.TypeStyle.caption.weight(.bold))
                            .foregroundStyle(BovexaTheme.Colors.white)
                            .padding(.horizontal, BovexaTheme.Space.sm)
                            .padding(.vertical, 4)
                            .background(BovexaTheme.Colors.tealDark)
                            .clipShape(Capsule())
                    }
                }

                assigneeChips

                if viewModel.canRespond {
                    respondButtons
                }
            }
        }
    }

    private var assigneeChips: some View {
        FlowLayout(spacing: BovexaTheme.Space.xs) {
            ForEach(event.assignee, id: \.self) { userId in
                assigneeChip(userId)
            }
        }
    }

    private func assigneeChip(_ userId: String) -> some View {
        let status = event.assigneeStatus[userId] ?? "pending"
        return HStack(spacing: 6) {
            Circle()
                .fill(memberColors.color(for: userId))
                .frame(width: 20, height: 20)
                .overlay(
                    Text((memberColors.firstName(for: userId) ?? "?").prefix(1).uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(BovexaTheme.Colors.white)
                )
            Text(memberColors.firstName(for: userId) ?? "collega")
                .font(BovexaTheme.TypeStyle.subheadline.weight(.semibold))
                .foregroundStyle(BovexaTheme.Colors.ink)
            if status != "accepted" {
                Text(status == "declined" ? "geweigerd" : "wacht")
                    .font(BovexaTheme.TypeStyle.caption.weight(.semibold))
                    .foregroundStyle(BovexaTheme.Colors.muted)
            }
        }
        .padding(.horizontal, BovexaTheme.Space.sm)
        .padding(.vertical, 6)
        .background(BovexaTheme.Colors.glass)
        .overlay(Capsule().strokeBorder(BovexaTheme.Colors.edge, lineWidth: 1))
        .clipShape(Capsule())
    }

    private var respondButtons: some View {
        HStack(spacing: BovexaTheme.Space.sm) {
            Button {
                Task {
                    await viewModel.respond("declined")
                    if viewModel.respondFailedAlert {
                        Haptics.warning()
                    } else {
                        dismiss()
                    }
                }
            } label: {
                Text("Weigeren")
                    .font(BovexaTheme.TypeStyle.headline)
                    .foregroundStyle(BovexaTheme.Colors.inkSoft)
                    .frame(maxWidth: .infinity, minHeight: 42)
            }
            .buttonStyle(.glassSecondaryBrand)

            Button {
                Task {
                    await viewModel.respond("accepted")
                    if viewModel.respondFailedAlert {
                        Haptics.warning()
                    } else {
                        Haptics.success()
                    }
                }
            } label: {
                Text("Accepteren")
                    .font(BovexaTheme.TypeStyle.headline)
                    .frame(maxWidth: .infinity, minHeight: 42)
            }
            .buttonStyle(.glassProminentBrand)
        }
    }

    private func detailRow(icon: String, text: String) -> some View {
        HStack(spacing: BovexaTheme.Space.sm) {
            Image(systemName: icon)
                .foregroundStyle(BovexaTheme.Colors.muted)
                .frame(width: 20)
            Text(text)
                .font(BovexaTheme.TypeStyle.body)
                .foregroundStyle(BovexaTheme.Colors.ink)
        }
    }
}

