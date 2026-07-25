import SwiftUI

/// Eén dag-cel in de maandgrid — dichtheid (stippen/balkjes/titel-chips) hangt af
/// van de actieve weergave (Compact/Gestapeld/Details).
struct MonthDayCellView: View {
    let cell: MonthDayCell
    let events: [AgendaEvent]
    let density: AgendaViewKind
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text("\(Calendar.current.component(.day, from: cell.date))")
                    .font(BovexaTheme.TypeStyle.footnote.weight(cell.isToday ? .bold : .regular))
                    .foregroundStyle(textColor)
                    .frame(width: 22, height: 22)
                    .background(cell.isToday ? BovexaTheme.Colors.teal : Color.clear)
                    .clipShape(Circle())

                densityContent
            }
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .top)
            .opacity(cell.isCurrentMonth ? 1 : 0.35)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var textColor: Color {
        cell.isToday ? BovexaTheme.Colors.white : BovexaTheme.Colors.ink
    }

    @ViewBuilder
    private var densityContent: some View {
        switch density {
        case .compact:
            dots
        case .gestapeld:
            bars
        case .details:
            titleChips
        case .dag, .lijst:
            EmptyView()
        }
    }

    private var dots: some View {
        HStack(spacing: 2) {
            ForEach(Array(events.prefix(4).enumerated()), id: \.offset) { _, event in
                Circle()
                    .fill(EventHelpers.eventColor(event))
                    .frame(width: 5, height: 5)
            }
        }
        .frame(height: 6)
    }

    private var bars: some View {
        VStack(spacing: 2) {
            ForEach(Array(events.prefix(3).enumerated()), id: \.offset) { _, event in
                RoundedRectangle(cornerRadius: 2)
                    .fill(EventHelpers.eventColor(event))
                    .frame(height: 3)
            }
        }
        .padding(.horizontal, 3)
    }

    private var titleChips: some View {
        let result = MonthDensity.titleChips(for: events, max: 3)
        return VStack(alignment: .leading, spacing: 2) {
            ForEach(result.shown) { event in
                Text(event.title)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(BovexaTheme.Colors.ink)
                    .lineLimit(1)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1.5)
                    .background(EventHelpers.eventColor(event).opacity(0.38))
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            }
            if result.overflow > 0 {
                Text("+\(result.overflow)")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(BovexaTheme.Colors.inkSoft)
            }
        }
        .padding(.horizontal, 2)
    }
}
