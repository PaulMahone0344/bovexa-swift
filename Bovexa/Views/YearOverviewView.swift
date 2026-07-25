import SwiftUI

/// Jaaroverzicht: 12 mini-maanden in 2 kolommen, badge per maand (dagen met
/// afspraken), dag tikken → springt naar die dag in de Agenda (dagweergave).
struct YearOverviewView: View {
    @StateObject private var viewModel: YearOverviewViewModel

    private let userId: String
    private let orgId: String?
    private let token: String
    private let onPickDay: (Date) -> Void

    private static let monthNamesShort = ["Jan", "Feb", "Mrt", "Apr", "Mei", "Jun", "Jul", "Aug", "Sep", "Okt", "Nov", "Dec"]
    private let columns = [GridItem(.flexible(), spacing: BovexaTheme.Space.md), GridItem(.flexible())]

    init(userId: String, orgId: String?, token: String, onPickDay: @escaping (Date) -> Void) {
        _viewModel = StateObject(wrappedValue: YearOverviewViewModel())
        self.userId = userId
        self.orgId = orgId
        self.token = token
        self.onPickDay = onPickDay
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                VStack(spacing: BovexaTheme.Space.md) {
                    yearHeader
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: BovexaTheme.Space.md) {
                            ForEach(0..<12, id: \.self) { month in
                                MiniMonthView(
                                    year: viewModel.year, month: month, shortName: Self.monthNamesShort[month],
                                    count: viewModel.dayCount(forMonth: month),
                                    hasEvents: { day in viewModel.hasEvents(month: month, day: day) },
                                    onPick: { day in
                                        if let date = Self.date(year: viewModel.year, month: month, day: day) {
                                            onPickDay(date)
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, BovexaTheme.Space.xl)
                        .padding(.bottom, BovexaTheme.Space.xl)
                    }
                }
            }
            .navigationTitle("Jaaroverzicht")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task(id: viewModel.year) {
            await viewModel.load(userId: userId, orgId: orgId, token: token)
        }
    }

    private var yearHeader: some View {
        HStack(spacing: BovexaTheme.Space.xl) {
            Button { viewModel.goToPreviousYear() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 22, weight: .semibold))
            }
            VStack(spacing: 2) {
                Text(String(viewModel.year))
                    .font(.system(size: BovexaTheme.TypeScale.h2, weight: .bold))
                Text("\(viewModel.totalDaysPlannedThisYear) dagen gepland")
                    .font(.system(size: BovexaTheme.TypeScale.tiny, weight: .semibold))
                    .foregroundStyle(BovexaTheme.Colors.muted)
            }
            .frame(minWidth: 120)
            Button { viewModel.goToNextYear() } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 22, weight: .semibold))
            }
        }
        .foregroundStyle(BovexaTheme.Colors.ink)
        .padding(.top, BovexaTheme.Space.sm)
    }

    private static func date(year: Int, month: Int, day: Int) -> Date? {
        var comps = DateComponents()
        comps.year = year; comps.month = month + 1; comps.day = day
        return Calendar.current.date(from: comps)
    }
}

private struct MiniMonthView: View {
    let year: Int
    let month: Int
    let shortName: String
    let count: Int
    let hasEvents: (Int) -> Bool
    let onPick: (Int) -> Void

    private static let weekLetters = ["M", "D", "W", "D", "V", "Z", "Z"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    private var cells: [Int?] { YearOverviewGrid.monthCells(year: year, month: month) }
    private var isCurrentMonth: Bool {
        let now = Calendar.current.dateComponents([.year, .month], from: Date())
        return now.year == year && (now.month ?? 0) - 1 == month
    }

    var body: some View {
        GlassCard(radius: BovexaTheme.Radius.md, padding: BovexaTheme.Space.sm) {
            VStack(spacing: 6) {
                header
                weekHeader
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(Array(cells.enumerated()), id: \.offset) { _, day in
                        dayCell(day)
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Text(shortName)
                .font(.system(size: BovexaTheme.TypeScale.small, weight: .bold))
                .foregroundStyle(isCurrentMonth ? BovexaTheme.Colors.accent : BovexaTheme.Colors.ink)
            Spacer()
            if count > 0 {
                Text("\(count)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(isCurrentMonth ? BovexaTheme.Colors.white : BovexaTheme.Colors.accent)
                    .padding(.horizontal, 6)
                    .frame(minWidth: 20, minHeight: 20)
                    .background(isCurrentMonth ? BovexaTheme.Colors.tealDark : BovexaTheme.Colors.teal.opacity(0.16))
                    .clipShape(Capsule())
            }
        }
    }

    private var weekHeader: some View {
        HStack(spacing: 0) {
            ForEach(Array(Self.weekLetters.enumerated()), id: \.offset) { _, letter in
                Text(letter)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(BovexaTheme.Colors.muted)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private func dayCell(_ day: Int?) -> some View {
        if let day {
            let isToday = Self.isToday(year: year, month: month, day: day)
            let has = hasEvents(day)
            Button {
                onPick(day)
            } label: {
                Text("\(day)")
                    .font(.system(size: 12, weight: (isToday || has) ? .bold : .medium))
                    .foregroundStyle(isToday ? BovexaTheme.Colors.white : (has ? BovexaTheme.Colors.accent : BovexaTheme.Colors.inkSoft))
                    .frame(width: 24, height: 24)
                    .background(isToday ? AnyShapeStyle(BovexaTheme.Colors.tealDark) : (has ? AnyShapeStyle(BovexaTheme.Colors.teal.opacity(0.18)) : AnyShapeStyle(Color.clear)))
                    .clipShape(Circle())
            }
        } else {
            Color.clear.frame(height: 24)
        }
    }

    private static func isToday(year: Int, month: Int, day: Int) -> Bool {
        var comps = DateComponents()
        comps.year = year; comps.month = month + 1; comps.day = day
        guard let date = Calendar.current.date(from: comps) else { return false }
        return Calendar.current.isDateInToday(date)
    }
}
