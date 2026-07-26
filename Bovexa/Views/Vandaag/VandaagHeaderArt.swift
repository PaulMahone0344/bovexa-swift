import SwiftUI

/// Zon met glinsters boven twee zachte heuvels, rechtsboven op Vandaag.
///
/// Bestaat om de kop niet leeg te laten: links staan de grote titel en de datum,
/// rechts stond alleen het bedrijfslogo en verder niets. Blijft bewust een
/// achtergrondtekening — lage dekking, geen omranding, geen tekst — zodat hij de
/// hero-kaart eronder niet beconcurreert.
struct VandaagHeaderArt: View {
    var body: some View {
        ZStack {
            // Heuvels: twee ellipsen die half buiten beeld vallen, zoals de mist
            // in de ondergrond. Ze staan onder de zon zodat die er los boven hangt.
            Ellipse()
                .fill(BovexaTheme.Colors.blue.opacity(0.09))
                .frame(width: 190, height: 60)
                .offset(x: -26, y: 34)

            Ellipse()
                .fill(BovexaTheme.Colors.blue.opacity(0.07))
                .frame(width: 140, height: 46)
                .offset(x: 30, y: 40)

            Circle()
                .fill(BovexaTheme.Colors.warm.opacity(0.85))
                .frame(width: 44, height: 44)
                .offset(x: 26, y: 0)

            Image(systemName: "sparkle")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(BovexaTheme.Colors.white.opacity(0.9))
                .offset(x: -30, y: -8)

            Image(systemName: "sparkle")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(BovexaTheme.Colors.white.opacity(0.8))
                .offset(x: -10, y: 12)
        }
        // Laag gehouden: op 96pt ontstond er een leeg gat tussen de datum en de
        // eerste kaart, en de tekening ging als een eigen blok lezen.
        .frame(width: 180, height: 62)
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#Preview {
    ZStack {
        AppBackground()
        VandaagHeaderArt()
    }
}
