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
    /// Hoogte waarop de balk binnenschuift: de ruimte onder het maandraster. De
    /// caller meet dat, want alleen daar is bekend hoeveel weken de maand heeft.
    var hoogte: CGFloat = 300
    /// Welke stand de balk nu heeft. De caller kiest de beginstand: een gewone tik
    /// zet hem onder de kalender, een dubbeltik meteen op volle hoogte.
    @Binding var stand: PresentationDetent

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
        // Twee standen. Een gewone tik houdt de balk precies onder de kalender —
        // op halve hoogte dekte hij de onderste weken af, en juist die dagen wil
        // je zien terwijl je dagen aantikt. Omhoog schuiven of een dubbeltik op de
        // dag zet hem op volle hoogte, want dan ga je de dag echt lezen.
        .presentationDetents([.height(hoogte), .large], selection: $stand)
        .presentationDragIndicator(.visible)
        // Bladeren door de maand blijft zo altijd mogelijk.
        .presentationBackgroundInteraction(.enabled(upThrough: .height(hoogte)))
    }
}
