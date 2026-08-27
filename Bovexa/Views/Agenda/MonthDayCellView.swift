import SwiftUI

/// Eén dag-cel in de maandgrid — dichtheid (stippen/balkjes/titel-chips) hangt af
/// van de actieve weergave (Compact/Gestapeld/Details).
struct MonthDayCellView: View {
    let cell: MonthDayCell
    let events: [AgendaEvent]
    let density: AgendaViewKind
    @ObservedObject var labelStore: LabelStore
    let onTap: () -> Void
    /// Dubbeltik: zelfde dag, maar de balk gaat meteen helemaal open.
    var onDoubleTap: (() -> Void)?

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text("\(Calendar.current.component(.day, from: cell.date))")
                    .font(BovexaTheme.TypeStyle.footnote.weight(cell.isToday ? .bold : .regular))
                    .foregroundStyle(textColor)
                    .frame(width: 22, height: 22)
                    .background(cell.isToday ? BovexaTheme.Colors.blue : Color.clear)
                    .clipShape(Circle())

                densityContent
            }
            // In de details-weergave staan er titels in de cel; op 52pt hoog werd
            // elke titel van twee regels alsnog afgekapt.
            .frame(maxWidth: .infinity, minHeight: density == .details ? 70 : 52, alignment: .top)
            .opacity(cell.isCurrentMonth ? 1 : 0.35)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // Dubbeltik vóór de gewone tik: SwiftUI geeft een count-2-gebaar voorrang
        // op de knop, dus één tik houdt de balk laag en twee tikken openen hem.
        .simultaneousGesture(TapGesture(count: 2).onEnded { onDoubleTap?() })
        // VoiceOver las alleen "15": geen maand, geen weekdag, geen aantal (5a).
        .accessibilityLabel("\(EventHelpers.longDay(cell.date)), \(events.count == 1 ? "1 afspraak" : "\(events.count) afspraken")")
        .accessibilityAddTraits(cell.isToday ? .isSelected : [])
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
                    .fill(EventHelpers.eventColor(event, labelStore: labelStore))
                    .frame(width: 5, height: 5)
            }
        }
        .frame(height: 6)
    }

    private var bars: some View {
        VStack(spacing: 2) {
            ForEach(Array(events.prefix(3).enumerated()), id: \.offset) { _, event in
                RoundedRectangle(cornerRadius: 2)
                    .fill(EventHelpers.eventColor(event, labelStore: labelStore))
                    .frame(height: 3)
            }
        }
        .padding(.horizontal, 3)
    }

    /// Twee chips i.p.v. drie. Bij drie was elke titel afgekapt ("Werke…",
    /// "Inspe…") en moest je de dag alsnog openen om te zien wat er stond. Met
    /// twee is er ruimte voor een leesbare regel, en de rest gaat naar "+N meer".
    private var titleChips: some View {
        let result = MonthDensity.titleChips(for: events, max: 2)
        return VStack(alignment: .leading, spacing: 2) {
            ForEach(result.shown) { event in
                Text(event.title)
                    // 9.5pt met krappe padding: bij 10pt paste "Inspectie" net
                    // niet en brak het middenin het woord af.
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(BovexaTheme.Colors.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 3)
                    .padding(.vertical, 2)
                    .background(EventHelpers.eventColor(event, labelStore: labelStore).opacity(chipOpacity(event)))
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            }
            if result.overflow > 0 {
                Text("+\(result.overflow) meer")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(BovexaTheme.Colors.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .padding(.horizontal, 4)
            }
        }
        .padding(.horizontal, 2)
    }

    /// Gewone afspraken rustiger, uitzonderingen sterker. Alles even hard
    /// gekleurd maakte een volle maand tot ruis waarin niets opvalt.
    private func chipOpacity(_ event: AgendaEvent) -> Double {
        event.category == .afwezig ? 0.55 : 0.28
    }
}
