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
                    token: authStore.token ?? "", memberColors: viewModel.memberColors
                )
            }
        }
        .onAppear {
            if days.isEmpty {
                days = Self.buildWindow(around: viewModel.dayViewFocusDate)
            }
            scrollDay = viewModel.dayViewFocusDate
        }
        .onChange(of: scrollDay) { _, newValue in
            if let newValue { viewModel.dayViewFocusDate = newValue }
        }
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
