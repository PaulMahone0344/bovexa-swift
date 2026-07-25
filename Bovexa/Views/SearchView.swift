import SwiftUI

/// Zoekscherm: autofocus-zoekbalk, live filter op titel/locatie/notities, rij → detail.
struct SearchView: View {
    @StateObject private var viewModel: SearchViewModel
    @ObservedObject var memberColors: MemberColors
    @Environment(\.dismiss) private var dismiss
    @FocusState private var searchFocused: Bool

    private let userId: String
    private let orgId: String?
    private let token: String
    private let currentUserOrgId: String?

    @State private var selectedEvent: AgendaEvent?

    init(userId: String, orgId: String?, token: String, currentUserOrgId: String?, memberColors: MemberColors) {
        _viewModel = StateObject(wrappedValue: SearchViewModel())
        self.userId = userId
        self.orgId = orgId
        self.token = token
        self.currentUserOrgId = currentUserOrgId
        self.memberColors = memberColors
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                VStack(spacing: BovexaTheme.Space.md) {
                    searchBar
                    resultsList
                }
                .padding(BovexaTheme.Space.xl)
            }
            .navigationTitle("Zoeken")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $selectedEvent) { event in
                EventDetailView(event: event, currentUserId: userId, currentUserOrgId: currentUserOrgId, token: token, memberColors: memberColors)
            }
        }
        .task {
            await viewModel.load(userId: userId, orgId: orgId, token: token)
            searchFocused = true
        }
    }

    private var searchBar: some View {
        HStack(spacing: BovexaTheme.Space.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(BovexaTheme.Colors.muted)
            TextField("Zoek in je afspraken…", text: $viewModel.query)
                .focused($searchFocused)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !viewModel.query.isEmpty {
                Button {
                    viewModel.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(BovexaTheme.Colors.muted)
                }
            }
        }
        .padding(.horizontal, BovexaTheme.Space.md)
        .frame(minHeight: 46)
        .background(BovexaTheme.Colors.glass)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(BovexaTheme.Colors.edge, lineWidth: 1))
    }

    @ViewBuilder
    private var resultsList: some View {
        let trimmed = viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            EmptyStateView(systemImage: "magnifyingglass", text: "Typ om te zoeken in al je afspraken.")
                .padding(.top, BovexaTheme.Space.xl)
        } else if viewModel.results.isEmpty {
            EmptyStateView(systemImage: "magnifyingglass", text: "Niks gevonden voor \u{201C}\(trimmed)\u{201D}.")
                .padding(.top, BovexaTheme.Space.xl)
        } else {
            ScrollView {
                VStack(spacing: BovexaTheme.Space.sm) {
                    ForEach(viewModel.results) { event in
                        Button {
                            Haptics.selection()
                            selectedEvent = event
                        } label: {
                            resultRow(event)
                        }
                    }
                }
            }
        }
    }

    private func resultRow(_ event: AgendaEvent) -> some View {
        GlassCard(radius: BovexaTheme.Radius.md, padding: BovexaTheme.Space.md) {
            HStack(spacing: BovexaTheme.Space.sm) {
                Circle()
                    .fill(EventHelpers.eventColor(event))
                    .frame(width: 9, height: 9)
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(BovexaTheme.TypeStyle.subheadline.weight(.bold))
                        .foregroundStyle(BovexaTheme.Colors.ink)
                        .lineLimit(1)
                    Text(metaText(event))
                        .font(BovexaTheme.TypeStyle.caption)
                        .foregroundStyle(BovexaTheme.Colors.muted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(BovexaTheme.Colors.muted)
            }
        }
    }

    private func metaText(_ event: AgendaEvent) -> String {
        var text = "\(EventHelpers.longDay(event.start)) · \(EventHelpers.rowTimeText(event))"
        if let location = event.location, !location.isEmpty {
            text += " · \(location)"
        }
        return text
    }
}
