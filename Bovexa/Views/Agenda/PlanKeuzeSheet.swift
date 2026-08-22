import SwiftUI

/// Kleine keuze-sheet achter de knop "Nieuwe afspraak": zelf invullen of door de
/// AI laten invullen.
///
/// Bewust de eerste stap en niet iets dat pas na het typen komt. Typen in de
/// Agenda zelf betekende dat de zin daarna herhaald moest worden om te laten zien
/// wat er meeging; nu kies je eerst de route en typ je dáár, in het veld dat er
/// toch al staat.
struct PlanKeuzeSheet: View {
    let onHandmatig: () -> Void
    let onAI: () -> Void

    var body: some View {
        ZStack {
            AppBackground()
            VStack(alignment: .leading, spacing: BovexaTheme.Space.md) {
                Text("Nieuwe afspraak")
                    .font(BovexaTheme.TypeStyle.title3)
                    .foregroundStyle(BovexaTheme.Colors.ink)
                    .padding(.top, BovexaTheme.Space.sm)

                keuzeRij(
                    icon: "square.and.pencil",
                    titel: "Zelf invullen",
                    uitleg: "Datum, tijd en details vul je zelf in.",
                    actie: onHandmatig
                )

                keuzeRij(
                    icon: "sparkles",
                    titel: "Met AI invullen",
                    uitleg: "Typ of spreek een zin; de planner leest het eruit.",
                    actie: onAI
                )

                Spacer(minLength: 0)
            }
            .padding(.horizontal, BovexaTheme.Space.xl)
            .padding(.bottom, BovexaTheme.Space.lg)
        }
        // Klein genoeg om de agenda erachter te blijven zien: dit is een afslag,
        // geen pagina.
        .presentationDetents([.height(290)])
        .presentationDragIndicator(.visible)
    }

    private func keuzeRij(icon: String, titel: String, uitleg: String, actie: @escaping () -> Void) -> some View {
        Button {
            Haptics.selection()
            actie()
        } label: {
            GlassCard(padding: BovexaTheme.Space.md) {
                HStack(spacing: BovexaTheme.Space.md) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: BovexaTheme.Gradients.blue, startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 34, height: 34)
                        Image(systemName: icon)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(BovexaTheme.Colors.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(titel)
                            .font(BovexaTheme.TypeStyle.subheadline.weight(.semibold))
                            .foregroundStyle(BovexaTheme.Colors.ink)
                        Text(uitleg)
                            .font(BovexaTheme.TypeStyle.footnote)
                            .foregroundStyle(BovexaTheme.Colors.muted)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(BovexaTheme.Colors.muted)
                }
            }
        }
        // Opmaak ín de label-closure (M11 patroon A): buiten de Button raakt hij
        // alleen zijn tekst in plaats van de hele kaart.
        .buttonStyle(.plain)
    }
}

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            PlanKeuzeSheet(onHandmatig: {}, onAI: {})
        }
}
