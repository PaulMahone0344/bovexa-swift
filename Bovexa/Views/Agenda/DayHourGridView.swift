import SwiftUI

/// Uurgrid 00:00-23:00 voor één dag: afspraak-blokken (overlap naast elkaar via
/// DayViewLayout), hele-dag-chips erboven, auto-scroll naar ±07:30.
struct DayHourGridView: View {
    let day: Date
    let events: [AgendaEvent]
    let currentUserId: String
    @ObservedObject var memberColors: MemberColors
    @ObservedObject var labelStore: LabelStore
    let onSelectEvent: (AgendaEvent) -> Void
    var onLongPressEmptyHour: (Int) -> Void = { _ in }

    private let hourHeight: CGFloat = 60
    private let gutterWidth: CGFloat = 40
    private let hours = Array(0..<24)

    /// Afwezigheid krijgt een baan over het raster (m7 plak 4), geen chip meer —
    /// het chipje bovenaan blijft voor overige hele-dag-zaken.
    private var allDayEvents: [AgendaEvent] { events.filter { $0.allDay && $0.category != .afwezig } }
    private var timedEvents: [AgendaEvent] { events.filter { !$0.allDay } }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: BovexaTheme.Space.sm) {
                    allDayChips

                    GeometryReader { geo in
                        ZStack(alignment: .topLeading) {
                            hourLines
                            absenceBands(availableWidth: geo.size.width - gutterWidth)
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
                        Haptics.selection()
                        onSelectEvent(event)
                    } label: {
                        Text(event.title)
                            .font(BovexaTheme.TypeStyle.footnote.weight(.medium))
                            .foregroundStyle(BovexaTheme.Colors.ink)
                            .padding(.horizontal, BovexaTheme.Space.sm)
                            .padding(.vertical, 4)
                            .glassEffect(.regular.tint(EventHelpers.eventColor(event, labelStore: labelStore).opacity(0.35)), in: .capsule)
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
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onLongPressGesture(minimumDuration: 0.42) {
                    Haptics.selection()
                    onLongPressEmptyHour(hour)
                }
                .id(hour)
            }
        }
    }

    /// Banen over het raster voor afwezigheid (m7 plak 4): één afwezige beslaat de
    /// volle beschikbare breedte, meerdere staan naast elkaar aan de linkerkant
    /// (AbsenceLayout — niet gestapeld, niet over elkaar heen), elk in de
    /// persoonskleur zodra er meer dan één is, anders in de afwezig-kleur.
    private func absenceBands(availableWidth: CGFloat) -> some View {
        let dayStart = Calendar.current.startOfDay(for: day)
        let bands = AbsenceLayout.bands(events, dayStart: dayStart)
        let safeWidth = max(availableWidth, 40)

        return ForEach(bands, id: \.event.id) { band in
            let columnWidth = safeWidth / CGFloat(band.columnCount)
            let color = band.columnCount > 1 ? memberColors.color(for: band.event.owner) : BovexaTheme.categoryColor(for: .afwezig)

            Button {
                Haptics.selection()
                onSelectEvent(band.event)
            } label: {
                AbsenceBandView(name: memberColors.firstName(for: band.event.owner) ?? band.event.title, color: color)
            }
            .buttonStyle(.plain)
            .frame(width: max(columnWidth - 2, 8), height: max(hourHeight * band.durationMinutes / 60 - 2, 16))
            .offset(x: gutterWidth + CGFloat(band.column) * columnWidth + 1, y: hourHeight * band.startMinutes / 60)
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
                Haptics.selection()
                onSelectEvent(item.event)
            } label: {
                EventBlockView(event: item.event, currentUserId: currentUserId, memberColors: memberColors, labelStore: labelStore)
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

/// Doorschijnende baan voor een afwezigheid — de uurlijnen blijven zichtbaar
/// (opacity), en gewone afspraken staan er als eventBlocks bovenop, dus zijn
/// altijd leesbaar (m7 plak 4).
private struct AbsenceBandView: View {
    let name: String
    let color: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(color.opacity(0.24))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(color.opacity(0.4), lineWidth: 1)
            )
            .overlay(alignment: .top) {
                Text(name)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 3)
                    .padding(.top, 4)
            }
    }
}

/// Eén afspraak-blok in het uurgrid.
///
/// v3: de afspraak van een collega krijgt een kleurstreep aan de zijkant in
/// diens persoonskleur, niet langer een volle omranding — een 2px rode kader
/// rondom een blok las als foutmelding in plaats van als "dit is van Daan".
/// Dezelfde markering als in de tijdlijn op Vandaag.
private struct EventBlockView: View {
    let event: AgendaEvent
    let currentUserId: String
    @ObservedObject var memberColors: MemberColors
    @ObservedObject var labelStore: LabelStore

    private var isColleague: Bool { event.owner != currentUserId }

    private var accent: Color {
        isColleague ? memberColors.color(for: event.owner) : EventHelpers.eventColor(event, labelStore: labelStore)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
    }

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(accent)
                .frame(width: isColleague ? 4 : 3)

            VStack(alignment: .leading, spacing: 1) {
                Text(EventHelpers.fmtTime(event.start))
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(BovexaTheme.Colors.inkSoft)
                Text(event.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(BovexaTheme.Colors.ink)
                    .lineLimit(1)
                if isColleague, let firstName = memberColors.firstName(for: event.owner) {
                    Text(firstName)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(accent)
                }
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .glassEffect(
            .regular.tint(EventHelpers.eventColor(event, labelStore: labelStore).opacity(0.28)),
            in: shape
        )
        .clipShape(shape)
    }
}
