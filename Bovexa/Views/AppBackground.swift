import SwiftUI

/// Achtergrond achter elk scherm.
///
/// v3: "daglicht" — koele teal-mist bovenin die naar warm zand onderin zakt,
/// met twee kleurvelden voor atmosfeer en een lichtstreek langs de bovenrand.
/// Liquid Glass werkt alleen als er kleurverschil ónder het glas doorschijnt;
/// de v2-ondergrond was bijna-wit, waardoor het glas optisch verdween.
struct AppBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: BovexaTheme.Gradients.backgroundSubtle,
                startPoint: .topLeading,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            GeometryReader { geo in
                // Koel veld linksboven — geeft de bovenkant van elk scherm diepte.
                Circle()
                    .fill(BovexaTheme.Colors.teal.opacity(0.30))
                    .frame(width: geo.size.width * 1.1)
                    .blur(radius: 110)
                    .offset(x: -geo.size.width * 0.38, y: -geo.size.height * 0.22)

                // Warm veld rechtsonder — tegenwicht, houdt de onderkant zacht.
                Circle()
                    .fill(BovexaTheme.Colors.warm.opacity(0.20))
                    .frame(width: geo.size.width * 0.85)
                    .blur(radius: 120)
                    .offset(x: geo.size.width * 0.45, y: geo.size.height * 0.62)

                // Lichtstreek langs de bovenrand: laat glas aan de bovenkant
                // oplichten, zoals licht dat over een oppervlak strijkt.
                LinearGradient(
                    colors: [Color.white.opacity(0.55), Color.white.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: geo.size.height * 0.28)
            }
            .ignoresSafeArea()
        }
    }
}

#Preview {
    AppBackground()
}
