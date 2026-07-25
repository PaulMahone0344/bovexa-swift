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

    init(event: AgendaEvent, currentUserId: String, currentUserOrgId: String?, token: String, memberColors: MemberColors) {
        _viewModel = StateObject(wrappedValue: EventDetailViewModel(
            event: event, currentUserId: currentUserId, currentUserOrgId: currentUserOrgId, token: token
        ))
        self.memberColors = memberColors
    }

    private var event: AgendaEvent { viewModel.event }
    private var isColleague: Bool { event.owner != viewModel.currentUserId }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
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
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.canDelete {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showDeleteConfirm = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(isDeleting)
                }
            }
        }
        .alert("Afspraak verwijderen", isPresented: $showDeleteConfirm) {
            Button("Annuleren", role: .cancel) {}
            Button("Verwijder", role: .destructive) {
                Task {
                    isDeleting = true
                    if await viewModel.delete() { dismiss() }
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
                        .font(.system(size: BovexaTheme.TypeScale.h2, weight: .bold))
                        .foregroundStyle(BovexaTheme.Colors.ink)
                }

                if isColleague, let firstName = memberColors.firstName(for: event.owner) {
                    Text("Van \(firstName)")
                        .font(.system(size: BovexaTheme.TypeScale.small, weight: .medium))
                        .foregroundStyle(memberColors.color(for: event.owner))
                }

                Divider().overlay(BovexaTheme.Colors.edge)

                detailRow(icon: "calendar", text: EventHelpers.longDay(event.start))
                detailRow(icon: "clock", text: EventHelpers.detailTimeText(event))

                if let location = event.location, !location.isEmpty {
                    detailRow(icon: "mappin.and.ellipse", text: location)
                }

                if let klant = event.klantNaam, !klant.isEmpty {
                    detailRow(icon: "person", text: klant)
                }

                if let notes = event.notes, !notes.isEmpty {
                    Divider().overlay(BovexaTheme.Colors.edge)
                    Text(notes)
                        .font(.system(size: BovexaTheme.TypeScale.body))
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
                        .font(.system(size: BovexaTheme.TypeScale.tiny, weight: .bold))
                        .foregroundStyle(BovexaTheme.Colors.accent)
                        .tracking(0.3)
                    Spacer()
                    if viewModel.isAssignedToMe {
                        Text("Aan jou")
                            .font(.system(size: BovexaTheme.TypeScale.tiny, weight: .bold))
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
                .font(.system(size: BovexaTheme.TypeScale.small, weight: .semibold))
                .foregroundStyle(BovexaTheme.Colors.ink)
            if status != "accepted" {
                Text(status == "declined" ? "geweigerd" : "wacht")
                    .font(.system(size: BovexaTheme.TypeScale.tiny, weight: .semibold))
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
                    if !viewModel.respondFailedAlert { dismiss() }
                }
            } label: {
                Text("Weigeren")
                    .font(.system(size: BovexaTheme.TypeScale.body, weight: .bold))
                    .foregroundStyle(BovexaTheme.Colors.inkSoft)
                    .frame(maxWidth: .infinity, minHeight: 42)
                    .background(BovexaTheme.Colors.glass)
                    .overlay(
                        RoundedRectangle(cornerRadius: BovexaTheme.Radius.md, style: .continuous)
                            .strokeBorder(BovexaTheme.Colors.edge, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: BovexaTheme.Radius.md, style: .continuous))
            }

            Button {
                Task { await viewModel.respond("accepted") }
            } label: {
                Text("Accepteren")
                    .font(.system(size: BovexaTheme.TypeScale.body, weight: .bold))
                    .foregroundStyle(BovexaTheme.Colors.white)
                    .frame(maxWidth: .infinity, minHeight: 42)
                    .background(BovexaTheme.Colors.tealDark)
                    .clipShape(RoundedRectangle(cornerRadius: BovexaTheme.Radius.md, style: .continuous))
            }
        }
    }

    private func detailRow(icon: String, text: String) -> some View {
        HStack(spacing: BovexaTheme.Space.sm) {
            Image(systemName: icon)
                .foregroundStyle(BovexaTheme.Colors.muted)
                .frame(width: 20)
            Text(text)
                .font(.system(size: BovexaTheme.TypeScale.body))
                .foregroundStyle(BovexaTheme.Colors.ink)
        }
    }
}

/// Wrappende chip-rij via het Layout-protocol (iOS 16+) — voor kleine lijsten
/// (toegewezenen) volstaat dit, geen aparte library nodig.
private struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth.isFinite ? maxWidth : x, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
