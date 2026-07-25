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
                    Text(label)
                        .font(.system(size: BovexaTheme.TypeScale.tiny, weight: .medium))
                        .foregroundStyle(BovexaTheme.Colors.muted)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(MonthGridBuilder.cells(for: viewModel.displayedMonth)) { cell in
                    MonthDayCellView(
                        cell: cell,
                        events: viewModel.eventsOnDay(cell.date),
                        density: viewModel.viewKind,
                        onTap: { viewModel.openDaySheet(cell.date) }
                    )
                }
            }
            .gesture(
                DragGesture(minimumDistance: 30)
                    .onEnded { value in
                        if value.translation.width < -40 {
                            viewModel.goToNextMonth()
                        } else if value.translation.width > 40 {
                            viewModel.goToPreviousMonth()
                        }
                    }
            )
        }
    }

    private var monthHeader: some View {
        HStack {
            Button {
                viewModel.goToPreviousMonth()
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
            .font(.system(size: BovexaTheme.TypeScale.title, weight: .semibold))
            .foregroundStyle(BovexaTheme.Colors.ink)

            Spacer()

            Button {
                viewModel.goToNextMonth()
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
