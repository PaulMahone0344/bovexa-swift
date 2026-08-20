import SwiftUI

/// Klanten: automatische lijst uit agenda_events gegroepeerd op klantnaam (valkuil F).
/// Geport uit klanten.tsx. Kaart tikken klapt uit naar "Komend"/"Eerder"; rij opent
/// het afspraak-detail. Lege lijst is een geldige uitkomst, ook bij maskering (valkuil G).
struct KlantenView: View {
    @StateObject private var viewModel: KlantenViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var openKey: String?
    @State private var selectedEvent: AgendaEvent?

    private let userId: String
    private let currentUserOrgId: String?
    private let token: String

    init(userId: String, orgId: String?, token: String) {
        _viewModel = StateObject(wrappedValue: KlantenViewModel(userId: userId, orgId: orgId, token: token))
        self.userId = userId
        self.currentUserOrgId = orgId
        self.token = token
    }

    private var now: Date { Date() }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                if viewModel.loading {
                    ProgressView().tint(BovexaTheme.Colors.accent)
                } else if viewModel.groups.isEmpty, viewModel.loadFailed {
                    LoadFailedNote(text: "Kon je klanten niet laden.", surface: .background)
                        .padding(.horizontal, BovexaTheme.Space.xl)
                } else if viewModel.groups.isEmpty {
                    EmptyStateView(systemImage: "person.2", text: "Klanten verschijnen hier zodra afspraken een klantnaam hebben.", surface: .background)
                        .padding(.horizontal, BovexaTheme.Space.xl)
                } else {
                    ScrollView {
                        VStack(spacing: BovexaTheme.Space.sm) {
                            ForEach(viewModel.groups) { group in
                                klantCard(group)
                            }
                        }
                        .padding(BovexaTheme.Space.xl)
                        .padding(.bottom, BovexaTheme.Space.tabBarClearance)
                    }
                    .refreshable { await viewModel.load() }
                }
            }
            .navigationTitle("Klanten")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(item: $selectedEvent) { event in
                // Zonder deze twee bleef een gewijzigde of verwijderde afspraak in
                // de klantenlijst staan; nogmaals tikken gaf dan een 404.
                EventDetailView(
                    event: event, currentUserId: userId, currentUserOrgId: currentUserOrgId, token: token,
                    memberColors: viewModel.memberColors, labelStore: viewModel.labelStore,
                    onChanged: { Task { await viewModel.load() } },
                    onDeleted: { _ in Task { await viewModel.load() } }
                )
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "chevron.left") }
                        .accessibilityLabel("Sluiten")
                }
            }
        }
        .task { await viewModel.load() }
    }

    private func klantCard(_ group: KlantGroup) -> some View {
        let open = openKey == group.id
        let (upcoming, past) = KlantGrouping.split(group.events, now: now)

        return Button {
            Haptics.selection()
            withAnimation(.snappy) { openKey = open ? nil : group.id }
        } label: {
            GlassCard {
                VStack(alignment: .leading, spacing: BovexaTheme.Space.sm) {
                    HStack(spacing: BovexaTheme.Space.md) {
                        Circle()
                            .fill(BovexaTheme.Colors.blue)
                            .frame(width: 40, height: 40)
                            .overlay(
                                Text(group.naam.prefix(1).uppercased())
                                    .font(BovexaTheme.TypeStyle.headline)
                                    .foregroundStyle(BovexaTheme.Colors.white)
                            )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(group.naam)
                                .font(BovexaTheme.TypeStyle.headline)
                                .foregroundStyle(BovexaTheme.Colors.ink)
                            Text(subtitle(group))
                                .font(BovexaTheme.TypeStyle.footnote)
                                .foregroundStyle(BovexaTheme.Colors.inkSoft)
                        }
                        Spacer()
                        Image(systemName: open ? "chevron.up" : "chevron.right")
                            .foregroundStyle(BovexaTheme.Colors.muted)
                    }

                    if open {
                        VStack(alignment: .leading, spacing: 4) {
                            if !upcoming.isEmpty {
                                Text("KOMEND")
                                    .font(BovexaTheme.TypeStyle.caption.weight(.bold))
                                    .foregroundStyle(BovexaTheme.Colors.accent)
                                    .padding(.top, BovexaTheme.Space.xs)
                                ForEach(upcoming) { event in
                                    eventRow(event)
                                }
                            }
                            if !past.isEmpty {
                                Text("EERDER")
                                    .font(BovexaTheme.TypeStyle.caption.weight(.bold))
                                    .foregroundStyle(BovexaTheme.Colors.accent)
                                    .padding(.top, BovexaTheme.Space.xs)
                                ForEach(past) { event in
                                    eventRow(event)
                                }
                            }
                        }
                        .padding(.top, BovexaTheme.Space.xs)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func subtitle(_ group: KlantGroup) -> String {
        let count = group.events.count
        let suffix = count == 1 ? "afspraak" : "afspraken"
        guard let telefoon = group.telefoon, !telefoon.isEmpty else { return "\(count) \(suffix)" }
        return "\(telefoon) · \(count) \(suffix)"
    }

    private func eventRow(_ event: AgendaEvent) -> some View {
        Button {
            Haptics.selection()
            selectedEvent = event
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(event.title)
                        .font(BovexaTheme.TypeStyle.subheadline.weight(.semibold))
                        .foregroundStyle(BovexaTheme.Colors.ink)
                        .lineLimit(1)
                    Text("\(EventHelpers.longDay(event.start)) · \(EventHelpers.rowTimeText(event))")
                        .font(BovexaTheme.TypeStyle.caption)
                        .foregroundStyle(BovexaTheme.Colors.muted)
                }
                Spacer()
            }
            .padding(.vertical, BovexaTheme.Space.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    KlantenView(userId: "u1", orgId: "org1", token: "tok")
}
