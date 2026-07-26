import SwiftUI

/// Achtergrond achter elk scherm.
///
/// v4: "daglicht" met vorm. De richting blijft v3 — koele teal-mist bovenin die
/// naar warm zand onderin zakt — maar de kleurvelden zijn strakker en staan zo
/// dat hun rand door de kaartkolom loopt. Reden: glas breekt licht op randen,
/// niet op egale vlakken; v3 blurde de velden tot mist en het glas werd mat.
/// Alle waardes komen uit `BovexaTheme.Orb`.
///
/// Bewust statisch: trage drift is geprobeerd en weer verwijderd. Bij een blur
/// van 55-65pt levert een verschuiving die klein genoeg is om rustig te blijven
/// een kleurverschil van hooguit 4/255 op — onzichtbaar, terwijl het scherm wel
/// continu opnieuw getekend wordt.
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
                orb(
                    color: BovexaTheme.Colors.orbCool,
                    opacity: BovexaTheme.Orb.coolOpacity,
                    center: BovexaTheme.Orb.coolCenter,
                    diameter: BovexaTheme.Orb.coolDiameter,
                    blur: BovexaTheme.Orb.coolBlur,
                    in: geo.size
                )

                orb(
                    color: BovexaTheme.Colors.orbMid,
                    opacity: BovexaTheme.Orb.midOpacity,
                    center: BovexaTheme.Orb.midCenter,
                    diameter: BovexaTheme.Orb.midDiameter,
                    blur: BovexaTheme.Orb.midBlur,
                    in: geo.size
                )

                orb(
                    color: BovexaTheme.Colors.orbMint,
                    opacity: BovexaTheme.Orb.warmOpacity,
                    center: BovexaTheme.Orb.warmCenter,
                    diameter: BovexaTheme.Orb.warmDiameter,
                    blur: BovexaTheme.Orb.warmBlur,
                    in: geo.size
                )

                // Lichtstreek langs de bovenrand: laat glas aan de bovenkant
                // oplichten, zoals licht dat over een oppervlak strijkt.
                LinearGradient(
                    colors: [
                        Color.white.opacity(BovexaTheme.Orb.topLightOpacity),
                        Color.white.opacity(0),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: geo.size.height * BovexaTheme.Orb.topLightHeight)
            }
            .ignoresSafeArea()
        }
    }

    private func orb(
        color: Color,
        opacity: Double,
        center: CGPoint,
        diameter: CGFloat,
        blur: CGFloat,
        in size: CGSize
    ) -> some View {
        Circle()
            .fill(color.opacity(opacity))
            .frame(width: size.width * diameter, height: size.width * diameter)
            .blur(radius: blur)
            .position(x: size.width * center.x, y: size.height * center.y)
    }
}

#Preview {
    AppBackground()
}
