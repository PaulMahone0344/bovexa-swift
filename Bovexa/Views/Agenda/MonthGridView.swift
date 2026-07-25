import SwiftUI

/// Maandgrid (Compact/Gestapeld/Details) — maand-pijlen of horizontaal vegen wisselt
/// van maand, vandaag gemarkeerd, dag-cel tikken opent de DaySheet.
struct MonthGridView: View {
    @ObservedObject var viewModel: AgendaViewModel
    let onYearTap: () -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)
    private let weekdayLabels = ["Ma", "Di", "Wo", "Do", "Vr", "Za", "Zo"]

    var body: some View {
        VStack(spacing: BovexaTheme.Space.md) {
            monthHeader

            HStack(spacing: 2) {
                ForEach(weekdayLabels, id: \.self) { label in
                    // Staat direct op de ondergrond (het maandraster zit niet in
                    // een GlassCard): sinds de v4-orbs is `muted` daar te licht.
                    Text(label)
                        .font(BovexaTheme.TypeStyle.caption.weight(.medium))
                        .foregroundStyle(BovexaTheme.Colors.inkSoft)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(MonthGridBuilder.cells(for: viewModel.displayedMonth)) { cell in
                    MonthDayCellView(
                        cell: cell,
                        events: viewModel.eventsOnDay(cell.date),
                        density: viewModel.viewKind,
                        onTap: {
                            Haptics.selection()
                            viewModel.openDaySheet(cell.date)
                        }
                    )
                }
            }
            .animation(.snappy, value: viewModel.displayedMonth)
            .gesture(
                DragGesture(minimumDistance: 30)
                    .onEnded { value in
                        if value.translation.width < -40 {
                            withAnimation(.snappy) { viewModel.goToNextMonth() }
                        } else if value.translation.width > 40 {
                            withAnimation(.snappy) { viewModel.goToPreviousMonth() }
                        }
                    }
            )
        }
    }

    private var monthHeader: some View {
        HStack {
            Button {
                withAnimation(.snappy) { viewModel.goToPreviousMonth() }
            } label: {
                Image(systemName: "chevron.left")
            }

            Spacer()

            HStack(spacing: BovexaTheme.Space.xs) {
                Text(monthName)
                Button(action: onYearTap) {
                    Text(yearText).underline()
                }
            }
            .font(BovexaTheme.TypeStyle.headline)
            .foregroundStyle(BovexaTheme.Colors.ink)

            Spacer()

            Button {
                withAnimation(.snappy) { viewModel.goToNextMonth() }
            } label: {
                Image(systemName: "chevron.right")
            }
        }
        .foregroundStyle(BovexaTheme.Colors.ink)
    }

    private var monthName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nl_NL")
        formatter.dateFormat = "MMMM"
        return formatter.string(from: viewModel.displayedMonth).capitalized
    }

    private var yearText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: viewModel.displayedMonth)
    }
}
