import SwiftUI

/// Meldingen: toewijzingen die op jouw akkoord wachten + bedrijfsmededelingen
/// (valkuil D). Geport uit meldingen.tsx. Plus-knop alleen admin/manager (valkuil E),
/// lang indrukken op je eigen mededeling verwijdert 'm.
struct MeldingenView: View {
    @StateObject private var viewModel: MeldingenViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var deleteTarget: Notice?

    init(userId: String, orgId: String?, token: String) {
        _viewModel = StateObject(wrappedValue: MeldingenViewModel(userId: userId, orgId: orgId, token: token))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: BovexaTheme.Space.lg) {
                        if viewModel.canPost {
                            composeSection
                        }

                        if !viewModel.pending.isEmpty {
                            pendingSection
                        }

                        if viewModel.isEmpty {
                            EmptyStateView(systemImage: "bell", text: "Hier verschijnen mededelingen van je team en toewijzingen die op je akkoord wachten.")
                        }

                        if !viewModel.notices.isEmpty {
                            noticesSection
                        }
                    }
                    .padding(BovexaTheme.Space.xl)
                    .padding(.bottom, BovexaTheme.Space.tabBarClearance)
                }
            }
            .navigationTitle("Meldingen")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "chevron.left") }
                }
                if viewModel.canPost {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            Haptics.selection()
                            withAnimation(.snappy) { viewModel.composeOpen.toggle() }
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
        }
        .task { await viewModel.load() }
        .alert("Mislukt", isPresented: Binding(get: { viewModel.postFailedMessage != nil }, set: { if !$0 { viewModel.postFailedMessage = nil } })) {
            Button("Oké", role: .cancel) {}
        } message: {
            Text(viewModel.postFailedMessage ?? "")
        }
        .alert("Mislukt", isPresented: $viewModel.respondFailedAlert) {
            Button("Oké", role: .cancel) {}
        } message: {
            Text("Kon je antwoord niet opslaan.")
        }
        .alert("Mislukt", isPresented: Binding(get: { viewModel.deleteFailedMessage != nil }, set: { if !$0 { viewModel.deleteFailedMessage = nil } })) {
            Button("Oké", role: .cancel) {}
        } message: {
            Text(viewModel.deleteFailedMessage ?? "")
        }
        .alert("Mededeling verwijderen", isPresented: Binding(get: { deleteTarget != nil }, set: { if !$0 { deleteTarget = nil } })) {
            Button("Annuleren", role: .cancel) {}
            Button("Verwijder", role: .destructive) {
                if let notice = deleteTarget {
                    Task { await viewModel.deleteNotice(notice) }
                }
            }
        } message: {
            Text("Weet je het zeker?")
        }
    }

    private var composeSection: some View {
        GlassCard(emphasis: .quiet) {
            VStack(alignment: .leading, spacing: BovexaTheme.Space.sm) {
                if viewModel.composeOpen {
                    Text("Nieuwe mededeling")
                        .font(BovexaTheme.TypeStyle.headline)
                        .foregroundStyle(BovexaTheme.Colors.ink)
                    TextField("Titel (optioneel)", text: $viewModel.composeTitle)
                        .textFieldStyle(.plain)
                        .padding(BovexaTheme.Space.sm)
                        .background(BovexaTheme.Colors.glassSoft)
                        .clipShape(RoundedRectangle(cornerRadius: BovexaTheme.Radius.sm, style: .continuous))
                    TextField("Bericht voor het hele team…", text: $viewModel.composeBody, axis: .vertical)
                        .lineLimit(3...6)
                        .textFieldStyle(.plain)
                        .padding(BovexaTheme.Space.sm)
                        .background(BovexaTheme.Colors.glassSoft)
                        .clipShape(RoundedRectangle(cornerRadius: BovexaTheme.Radius.sm, style: .continuous))
                    Button {
                        Task {
                            await viewModel.submit()
                            if viewModel.postFailedMessage == nil { Haptics.success() }
                        }
                    } label: {
                        if viewModel.posting {
                            ProgressView().tint(BovexaTheme.Colors.white).frame(maxWidth: .infinity)
                        } else {
                            Text("Plaatsen").frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.glassProminentBrand)
                    .disabled(!viewModel.canSubmit)
                }
            }
        }
    }

    private var pendingSection: some View {
        VStack(alignment: .leading, spacing: BovexaTheme.Space.sm) {
            Text("WACHT OP JOUW AKKOORD")
                .font(BovexaTheme.TypeStyle.caption.weight(.bold))
                .foregroundStyle(BovexaTheme.Colors.accent)
                .tracking(0.3)

            ForEach(viewModel.pending) { event in
                pendingCard(event)
            }
        }
    }

    private func pendingCard(_ event: AgendaEvent) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BovexaTheme.Space.xs) {
                Text(event.title)
                    .font(BovexaTheme.TypeStyle.headline)
                    .foregroundStyle(BovexaTheme.Colors.ink)
                Text("\(EventHelpers.longDay(event.start)) · \(EventHelpers.rowTimeText(event))")
                    .font(BovexaTheme.TypeStyle.footnote)
                    .foregroundStyle(BovexaTheme.Colors.inkSoft)

                HStack(spacing: BovexaTheme.Space.sm) {
                    Button {
                        Task { await viewModel.respond(event, status: "declined") }
                    } label: {
                        Text("Weigeren").frame(maxWidth: .infinity, minHeight: 42)
                    }
                    .buttonStyle(.glassSecondaryBrand)
                    .disabled(viewModel.answeringId == event.id)

                    Button {
                        Task {
                            await viewModel.respond(event, status: "accepted")
                            if !viewModel.respondFailedAlert { Haptics.success() }
                        }
                    } label: {
                        if viewModel.answeringId == event.id {
                            ProgressView().tint(BovexaTheme.Colors.white).frame(maxWidth: .infinity, minHeight: 42)
                        } else {
                            Text("Accepteren").frame(maxWidth: .infinity, minHeight: 42)
                        }
                    }
                    .buttonStyle(.glassProminentBrand)
                    .disabled(viewModel.answeringId == event.id)
                }
                .padding(.top, BovexaTheme.Space.xs)
            }
        }
    }

    private var noticesSection: some View {
        VStack(alignment: .leading, spacing: BovexaTheme.Space.sm) {
            ForEach(viewModel.notices) { notice in
                GlassCard(emphasis: .quiet) {
                    VStack(alignment: .leading, spacing: BovexaTheme.Space.xs) {
                        if let title = notice.title, !title.isEmpty {
                            Text(title)
                                .font(BovexaTheme.TypeStyle.headline)
                                .foregroundStyle(BovexaTheme.Colors.ink)
                        }
                        Text(notice.body)
                            .font(BovexaTheme.TypeStyle.subheadline)
                            .foregroundStyle(BovexaTheme.Colors.inkSoft)
                        Text("\(notice.authorNaam.isEmpty ? "Team" : notice.authorNaam) · \(NoticeHelpers.relativeTime(notice.created))")
                            .font(BovexaTheme.TypeStyle.caption)
                            .foregroundStyle(BovexaTheme.Colors.muted)
                    }
                }
                .onLongPressGesture(minimumDuration: 0.45) {
                    guard viewModel.canDelete(notice) else { return }
                    Haptics.selection()
                    deleteTarget = notice
                }
            }
        }
    }
}

#Preview {
    MeldingenView(userId: "u1", orgId: "org1", token: "tok")
}
