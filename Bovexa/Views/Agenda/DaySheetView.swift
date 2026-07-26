import SwiftUI

/// Popup bij een dag-tik in de maandweergave.
///
/// 26 juli kort inline onder de kalender geprobeerd (DayPanelView) en op verzoek
/// weer een sheet geworden: onder een volle maand vroeg dat paneel om scrollen.
/// De inhoud is wél die van toen — dagtotaal, de afspraken, "Open dag" en
/// "Afspraak plannen" — in plaats van alleen een lijstje.
struct DaySheetView: View {
    let day: Date
    let events: [AgendaEvent]
    let currentUserId: String
    @ObservedObject var memberColors: MemberColors
    @ObservedObject var labelStore: LabelStore
    let onOpenDay: () -> Void
    let onSelectEvent: (AgendaEvent) -> Void
    var onPlanAppointment: () -> Void = {}

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                DayPanelView(
                    day: day,
                    events: events,
                    currentUserId: currentUserId,
                    memberColors: memberColors,
                    labelStore: labelStore,
                    onOpenDay: onOpenDay,
                    onSelectEvent: onSelectEvent,
                    onPlanAppointment: onPlanAppointment
                )
                .padding(BovexaTheme.Space.xl)
            }
        }
        // Halfhoog openen: zo blijft de maand waar je vandaan komt zichtbaar, en
        // een drukke dag kun je uitklappen.
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
