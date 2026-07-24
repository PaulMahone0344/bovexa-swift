import SwiftUI

/// Uurgrid 00:00-23:00 voor één dag: afspraak-blokken (overlap naast elkaar via
/// DayViewLayout), hele-dag-chips erboven, auto-scroll naar ±07:30.
struct DayHourGridView: View {
    let day: Date
    let events: [AgendaEvent]
    let currentUserId: String
    @ObservedObject var memberColors: MemberColors
    let onSelectEvent: (AgendaEvent) -> Void

    private let hourHeight: CGFloat = 60
    private let gutterWidth: CGFloat = 40
    private let hours = Array(0..<24)

    private var allDayEvents: [AgendaEvent] { events.filter(\.allDay) }
    private var timedEvents: [AgendaEvent] { events.filter { !$0.allDay } }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: BovexaTheme.Space.sm) {
                    allDayChips

                    GeometryReader { geo in
                        ZStack(alignment: .topLeading) {
                            hourLines
                            eventBlocks(availableWidth: geo.size.width - gutterWidth)
                        }
                    }
                    .frame(height: hourHeight * 24)
                }
                .padding(.horizontal, BovexaTheme.Space.md)
            }
            .onAppear {
                proxy.scrollTo(7, anchor: .top)
            }
        }
    }

    @ViewBuilder
    private var allDayChips: some View {
        if !allDayEvents.isEmpty {
            HStack(spacing: BovexaTheme.Space.xs) {
                ForEach(allDayEvents) { event in
                    Button {
                        onSelectEvent(event)
                    } label: {
                        Text(event.title)
                            .font(.system(size: BovexaTheme.TypeScale.small, weight: .medium))
                            .foregroundStyle(BovexaTheme.Colors.ink)
                            .padding(.horizontal, BovexaTheme.Space.sm)
                            .padding(.vertical, 4)
                            .background(EventHelpers.eventColor(event).opacity(0.28))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
        }
    }

    private var hourLines: some View {
        VStack(spacing: 0) {
            ForEach(hours, id: \.self) { hour in
                HStack(alignment: .top, spacing: BovexaTheme.Space.xs) {
                    Text(String(format: "%02d:00", hour))
                        .font(.system(size: BovexaTheme.TypeScale.tiny))
                        .foregroundStyle(BovexaTheme.Colors.muted)
                        .frame(width: gutterWidth - BovexaTheme.Space.xs, alignment: .leading)
                    Rectangle()
                        .fill(BovexaTheme.Colors.edgeSoft)
                        .frame(height: 1)
                }
                .frame(height: hourHeight, alignment: .top)
                .id(hour)
            }
        }
    }

    private func eventBlocks(availableWidth: CGFloat) -> some View {
        let positioned = DayViewLayout.layout(timedEvents)
        let dayStart = Calendar.current.startOfDay(for: day)
        let safeWidth = max(availableWidth, 40)

        return ForEach(positioned, id: \.event.id) { item in
            let startOffsetMinutes = item.event.start.timeIntervalSince(dayStart) / 60
            let durationMinutes = max(15, Double(EventHelpers.durationMin(item.event) ?? 30))
            let columnWidth = safeWidth / CGFloat(item.columnCount)

            Button {
                onSelectEvent(item.event)
            } label: {
                EventBlockView(event: item.event, currentUserId: currentUserId, memberColors: memberColors)
            }
            .buttonStyle(.plain)
            .frame(width: max(columnWidth - 4, 24), height: max(hourHeight * durationMinutes / 60 - 2, 16), alignment: .topLeading)
            .offset(
                x: gutterWidth + CGFloat(item.column) * columnWidth + 2,
                y: hourHeight * startOffsetMinutes / 60
            )
        }
    }
}

/// Eén afspraak-blok in het uurgrid — collega-rand in persoonskleur + voornaam.
private struct EventBlockView: View {
    let event: AgendaEvent
    let currentUserId: String
    @ObservedObject var memberColors: MemberColors

    private var isColleague: Bool { event.owner != currentUserId }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(EventHelpers.fmtTime(event.start))
                .font(.system(size: 9, weight: .semibold))
            Text(event.title)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(1)
            if isColleague, let firstName = memberColors.firstName(for: event.owner) {
                Text(firstName)
                    .font(.system(size: 8))
            }
        }
        .foregroundStyle(BovexaTheme.Colors.ink)
        .padding(4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(EventHelpers.eventColor(event).opacity(0.28))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(
                    isColleague ? memberColors.color(for: event.owner) : EventHelpers.eventColor(event),
                    lineWidth: isColleague ? 2 : 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}
