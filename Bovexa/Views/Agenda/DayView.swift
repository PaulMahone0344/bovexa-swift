import SwiftUI

/// Dagweergave: horizontale dagcarousel + uurgrid, "‹ maand"-pill terug naar
/// de maandweergave die actief was vóór het openen van deze dag.
struct DayView: View {
    @EnvironmentObject private var authStore: AuthStore
    @ObservedObject var viewModel: AgendaViewModel
    let currentUserId: String
    var onPlanAtHour: (Int, Date) -> Void = { _, _ in }

    private var currentUserOrgId: String? {
        if case .loggedIn(let user) = authStore.phase { return user.defaultOrg }
        return nil
    }

    @State private var days: [Date] = []
    @State private var scrollDay: Date?
    @State private var selectedEvent: AgendaEvent?
    /// De dag waar de carousel naartoe moet. Zolang die er staat, is elke andere
    /// scrollpositie een tussenstand van het scrollen zelf en mag hij de focus niet
    /// overschrijven — anders bepaalt een halve scrollbeweging naar welke maand de
    /// "‹ maand"-knop terugkeert.
    @State private var pendingFocus: Date?

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                VStack(spacing: BovexaTheme.Space.md) {
                    header

                    ScrollView(.horizontal) {
                        LazyHStack(spacing: 0) {
                            ForEach(days, id: \.self) { day in
                                DayHourGridView(
                                    day: day,
                                    events: viewModel.eventsOnDay(day),
                                    currentUserId: currentUserId,
                                    memberColors: viewModel.memberColors,
                                    labelStore: viewModel.labelStore,
                                    onSelectEvent: { selectedEvent = $0 },
                                    onLongPressEmptyHour: { hour in onPlanAtHour(hour, day) }
                                )
                                .containerRelativeFrame(.horizontal)
                                .id(day)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollTargetBehavior(.paging)
                    .scrollPosition(id: $scrollDay)
                }
            }
            .navigationDestination(item: $selectedEvent) { event in
                EventDetailView(
                    event: event, currentUserId: currentUserId, currentUserOrgId: currentUserOrgId,
                    token: authStore.token ?? "", memberColors: viewModel.memberColors, labelStore: viewModel.labelStore,
                    onChanged: { Task { await viewModel.reload() } },
                    onDeleted: { recordId in
                        viewModel.removeLocally(recordId: recordId)
                        Task { await viewModel.reload() }
                    }
                )
            }
        }
        .onAppear { focus(on: viewModel.dayViewFocusDate) }
        // De focus kan verschuiven terwijl dit scherm al staat (planner klaar,
        // dag gekozen in het jaaroverzicht). Zonder dit blijft de carousel op de
        // vorige dag staan en lijkt de nieuwe afspraak te ontbreken.
        .onChange(of: viewModel.dayViewFocusDate) { _, newValue in
            guard newValue != scrollDay else { return }
            focus(on: newValue)
        }
        .onChange(of: scrollDay) { _, newValue in
            guard let newValue else { return }
            if let pendingFocus {
                if newValue == pendingFocus { self.pendingFocus = nil }
                return
            }
            viewModel.dayViewFocusDate = newValue
        }
    }

    /// Zet de carousel op `day`. Het venster wordt opnieuw gebouwd zodra de dag er
    /// niet in zit: het loopt zestig dagen ver, en een afspraak verder weg was
    /// anders onbereikbaar — de scroll bleef dan op de eerste dag van het venster.
    private func focus(on day: Date) {
        let target = Calendar.current.startOfDay(for: day)
        if !days.contains(target) {
            days = Self.buildWindow(around: target)
        }
        pendingFocus = target
        scrollDay = target
    }

    private var header: some View {
        HStack {
            Button {
                viewModel.backToMonth()
            } label: {
                Label(monthAbbreviation, systemImage: "chevron.left")
                    .font(BovexaTheme.TypeStyle.footnote.weight(.semibold))
            }
            .buttonStyle(.glassSecondaryBrand)
            .tint(BovexaTheme.Colors.accent)

            Spacer()

            Text(EventHelpers.longDay(scrollDay ?? viewModel.dayViewFocusDate))
                .font(BovexaTheme.TypeStyle.subheadline)
                .foregroundStyle(BovexaTheme.Colors.muted)
        }
        .padding(.horizontal, BovexaTheme.Space.lg)
        .padding(.top, BovexaTheme.Space.sm)
    }

    private var monthAbbreviation: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nl_NL")
        formatter.dateFormat = "MMM"
        return formatter.string(from: viewModel.dayViewFocusDate).capitalized
    }

    private static func buildWindow(around center: Date, radius: Int = 60, calendar: Calendar = .current) -> [Date] {
        let start = calendar.startOfDay(for: center)
        return (-radius...radius).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }
}
