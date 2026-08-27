import SwiftUI

/// "Nieuwe afspraak" (M12, herzien 22 aug): het handmatige formulier, in een sheet.
///
/// Hier stonden eerst twee keuzekaarten (MET AI / HANDMATIG), daarna het formulier
/// met een AI-regel erboven. Allebei weg: de keuze valt nu vóór dit scherm, in de
/// plan-pill. Typ je daar een zin, dan vraagt `PlanKeuzeSheet` wat ermee moet
/// gebeuren; is het veld leeg, dan valt er niets te lezen en is dit formulier de
/// enige zinnige uitkomst. Een tweede AI-ingang hier is dan dubbelop.
struct NieuweAfspraakView: View {
    /// Waar de gebruiker vandaan kwam: een dag, een leeg uur, of een getypte zin.
    let seed: NieuweAfspraakSeed
    let userId: String
    let token: String
    let org: String?
    @ObservedObject var memberColors: MemberColors
    @ObservedObject var labelStore: LabelStore
    /// Standaardduur van het bedrijf voor het formulier; valt terug op
    /// `EventEditorViewModel.fallbackDurationMin` als het bedrijf er geen heeft.
    var defaultDurationMin: Int = EventEditorViewModel.fallbackDurationMin
    /// Datum van de zojuist gemaakte afspraak — de Agenda springt daarheen en laadt
    /// opnieuw. Zonder dit staat een nieuwe afspraak er pas na een herstart.
    let onConfirmed: (Date) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    EventEditorView(
                        seed: seed, currentUserId: userId, org: org ?? "",
                        companyName: memberColors.orgName ?? "Bedrijf", token: token,
                        members: memberColors.members, labelStore: labelStore,
                        defaultDurationMin: defaultDurationMin,
                        // Het formulier is de enige pagina, dus Annuleren sluit de
                        // sheet in plaats van een stap terug te gaan.
                        onCancel: { dismiss() },
                        onSaved: { created in
                            // Haptics.success() staat al in EventEditorView.
                            onConfirmed(created.start)
                            dismiss()
                        }
                    )
                    .padding(BovexaTheme.Space.xl)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Nieuwe afspraak")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                SheetCloseButton { dismiss() }
            }
        }
        // Valkuil D: het formulier is lang en heeft een notitieveld. Op een halve
        // sheet duwt het toetsenbord de knoppen eronder volledig uit beeld.
        .presentationDetents([.large])
    }
}

#Preview {
    NieuweAfspraakView(
        seed: .empty, userId: "u1", token: "tok", org: "org1",
        memberColors: MemberColors(), labelStore: LabelStore(), onConfirmed: { _ in }
    )
}
