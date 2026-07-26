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

    /// Breedte van één afwezigheidsstrook.
    private static let absenceLaneWidth: CGFloat = 22

    /// Het uur waar het raster op opent; de naam in een afwezigheidsbaan zakt
    /// hiernaartoe zodat hij zichtbaar is zodra je de dag opent. Op vandaag is dat
    /// het uur van de nu-lijn, op andere dagen de ochtend.
    private var scrollAnchorHour: Int { DayNowIndicator.anchorHour(now: Date(), day: day) }

    /// Afwezigheid krijgt een baan over het raster (m7 plak 4), geen chip meer —
    /// het chipje bovenaan blijft voor overige hele-dag-zaken.
    private var allDayEvents: [AgendaEvent] { events.filter { $0.allDay && $0.category != .afwezig } }
    private var timedEvents: [AgendaEvent] { AbsenceLayout.timedNonAbsence(events) }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: BovexaTheme.Space.sm) {
                    allDayChips

                    GeometryReader { geo in
                        let grid = max(geo.size.width - gutterWidth, 40)
                        let bands = AbsenceLayout.bands(events, dayStart: Calendar.current.startOfDay(for: day))
                        // Stroken en afspraken delen de breedte in plaats van over
                        // elkaar heen te liggen: de blokken begonnen anders bovenop
                        // de strook, waardoor die er half onder verdween.
                        let laneWidth = laneWidth(bandCount: bands.count, gridWidth: grid)
                        let laneInset = laneWidth == 0 ? 0 : CGFloat(bands.count) * (laneWidth + 2)

                        ZStack(alignment: .topLeading) {
                            hourLines
                            absenceBands(bands, laneWidth: laneWidth)
                            eventBlocks(availableWidth: grid - laneInset, xInset: laneInset)
                            nowLine(gridWidth: grid)
                        }
                    }
                    .frame(height: hourHeight * 24)
                }
                .padding(.horizontal, BovexaTheme.Space.md)
            }
            .onAppear {
                proxy.scrollTo(scrollAnchorHour, anchor: .top)
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
                            .contentShape(.capsule)
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
                        .foregroundStyle(BovexaTheme.Colors.gridHour)
                        .frame(width: gutterWidth - BovexaTheme.Space.xs, alignment: .leading)
                    Rectangle()
                        .fill(BovexaTheme.Colors.gridLine)
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

    /// Nu-lijn zoals de iOS Agenda: een dunne streep met een bolletje op de
    /// urenkolom, alleen op de dag die vandaag is. In `warm` — het enige
    /// signaaltoken in het palet, en amber op blauw blijft over de volle hoogte van
    /// het verloop leesbaar. Niet in een categorie- of persoonskleur: die betekenen
    /// hier iets anders. Verschuift elke minuut via TimelineView; hij ligt bovenop
    /// de blokken maar vangt geen tikken, anders zou de lijn een afspraak afdekken.
    @ViewBuilder
    private func nowLine(gridWidth: CGFloat) -> some View {
        TimelineView(.everyMinute) { context in
            if let minutes = DayNowIndicator.minutesFromMidnight(now: context.date, day: day) {
                HStack(spacing: 0) {
                    Circle()
                        .fill(BovexaTheme.Colors.warm)
                        .frame(width: 7, height: 7)
                    Rectangle()
                        .fill(BovexaTheme.Colors.warm)
                        .frame(height: 1.5)
                }
                .frame(width: gridWidth + 3.5)
                .offset(x: gutterWidth - 3.5, y: hourHeight * minutes / 60 - 0.75)
                .allowsHitTesting(false)
                .accessibilityElement()
                .accessibilityLabel("Nu, \(EventHelpers.fmtTime(context.date))")
            }
        }
    }

    /// Nooit meer dan een derde van het raster opeisen, ook niet bij veel
    /// afwezigen; de rest blijft voor de afspraken.
    private func laneWidth(bandCount: Int, gridWidth: CGFloat) -> CGFloat {
        guard bandCount > 0 else { return 0 }
        return min(Self.absenceLaneWidth, gridWidth / 3 / CGFloat(bandCount))
    }

    /// Banen over het raster voor afwezigheid (m7 plak 4): smalle strook per
    /// afwezige, links tegen de urenkolom, in diens persoonskleur.
    ///
    /// Eerder vulde één afwezige de volle breedte. Een hele-dag-vakantie legde dan
    /// een amberwaas over het complete raster: over het blauw dooft amber uit tot
    /// vaal grijsbeige en je eigen afspraken lagen middenin die soep. Een smalle
    /// strook zegt hetzelfde — deze persoon is de hele dag weg — zonder de dag te
    /// verkleuren.
    private func absenceBands(_ bands: [AbsenceBand], laneWidth: CGFloat) -> some View {
        ForEach(bands, id: \.event.id) { band in
            Button {
                Haptics.selection()
                onSelectEvent(band.event)
            } label: {
                AbsenceBandView(
                    name: memberColors.firstName(for: band.event.owner) ?? band.event.title,
                    color: memberColors.color(for: band.event.owner),
                    // De naam stond bovenaan de baan, dus bij een hele-dag-baan op
                    // 00:00 — en daar kijk je nooit, want het raster opent op 07:00.
                    // Je zag een gekleurde strook zonder te weten van wie. Nu zakt
                    // het label mee naar het uur waar je binnenkomt.
                    labelOffset: max(0, CGFloat(scrollAnchorHour) * hourHeight - hourHeight * band.startMinutes / 60)
                )
            }
            .buttonStyle(.plain)
            .frame(width: laneWidth, height: max(hourHeight * band.durationMinutes / 60 - 2, 16))
            .offset(x: gutterWidth + CGFloat(band.column) * (laneWidth + 2), y: hourHeight * band.startMinutes / 60)
        }
    }

    private func eventBlocks(availableWidth: CGFloat, xInset: CGFloat) -> some View {
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
                x: gutterWidth + xInset + CGFloat(item.column) * columnWidth + 2,
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
    /// Hoe ver de initiaal vanaf de bovenkant van de baan zakt, zodat hij op het
    /// uur staat waar het raster opent in plaats van op 00:00.
    let labelOffset: CGFloat

    private var initial: String {
        guard let first = name.first else { return "?" }
        return String(first).uppercased()
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(color.opacity(0.26))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(color.opacity(0.55), lineWidth: 1)
            )
            .overlay(alignment: .top) {
                // Een initiaal in plaats van de volle naam: de strook is smal, en
                // dit is dezelfde markering als in de tijdlijn op Vandaag. Wie het
                // precies is staat in het detail als je de baan aantikt.
                Text(initial)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(BovexaTheme.Colors.white)
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(color))
                    .offset(y: labelOffset + 4)
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

    /// Eigen afspraak is een gevuld vlak in de categorie- of labelkleur, die van
    /// een collega alleen een rand in diens persoonskleur. Zo is in één oogopslag
    /// te zien wat van jou is zonder de naam te lezen. v3 had ook een omranding en
    /// draaide die terug omdat een dik kader als foutmelding las; het verschil is
    /// dat het vlak nu neutraal blijft, dus de rand hoeft niet hard te zijn.
    private var glass: Glass {
        isColleague ? .regular : .regular.tint(EventHelpers.eventColor(event, labelStore: labelStore).opacity(0.28))
    }

    var body: some View {
        HStack(spacing: 0) {
            if !isColleague {
                Rectangle()
                    .fill(accent)
                    .frame(width: 3)
            }

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
        .glassEffect(glass, in: shape)
        .clipShape(shape)
        .overlay {
            if isColleague {
                shape.strokeBorder(accent, lineWidth: 2)
            }
        }
        // Zonder dit is alleen de tekst raakbaar: glas telt niet mee voor
        // hit-testing. Bij een afwezigheidsbaan eronder (die wél een gevulde
        // shape is) opende een tik in het blok de afwezigheid van de collega.
        .contentShape(shape)
    }
}
