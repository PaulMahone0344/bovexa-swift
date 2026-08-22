import SwiftUI

/// Kleine keuze-sheet na het typen in de plan-pill: zelf invullen of door de AI
/// laten invullen.
///
/// Waarom hier wél een keuze en bij een leeg veld niet: met een lege pill weet de
/// app dat er niets te lezen valt, dus dan is het formulier de enige zinnige
/// uitkomst. Heb je een zin getypt, dan zijn beide routes echt mogelijk — en
/// zonder keuze verdween je zin altijd in de AI-planner, ook als je 'm gewoon als
/// titel bedoelde.
struct PlanKeuzeSheet: View {
    /// De zin die de gebruiker net typte of insprak; hij moet 'm terugzien, anders
    /// is niet duidelijk wat er met de keuze meegaat.
    let zin: String
    let onHandmatig: () -> Void
    let onAI: () -> Void

    var body: some View {
        ZStack {
            AppBackground()
            VStack(alignment: .leading, spacing: BovexaTheme.Space.md) {
                Text(zin)
                    .font(BovexaTheme.TypeStyle.subheadline)
                    .foregroundStyle(BovexaTheme.Colors.muted)
                    .lineLimit(2)
                    .padding(.top, BovexaTheme.Space.sm)

                keuzeRij(
                    icon: "square.and.pencil",
                    titel: "Zelf invullen",
                    uitleg: "Als titel in het formulier; datum en tijd zet je zelf.",
                    actie: onHandmatig
                )

                keuzeRij(
                    icon: "sparkles",
                    titel: "Met AI invullen",
                    uitleg: "De planner leest de dag, de tijd en de naam eruit.",
                    actie: onAI
                )

                Spacer(minLength: 0)
            }
            .padding(.horizontal, BovexaTheme.Space.xl)
            .padding(.bottom, BovexaTheme.Space.lg)
        }
        // Klein genoeg om de agenda erachter te blijven zien: dit is een afslag,
        // geen pagina.
        .presentationDetents([.height(300)])
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
            PlanKeuzeSheet(zin: "morgen 15:00 tandarts in Amsterdam", onHandmatig: {}, onAI: {})
        }
}
