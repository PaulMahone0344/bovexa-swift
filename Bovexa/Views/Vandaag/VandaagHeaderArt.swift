import SwiftUI

/// Zon met glinsters achter een zachte berg, rechtsboven op Vandaag.
///
/// Bestaat om de kop niet leeg te laten: links staan de grote titel en de datum,
/// rechts stond alleen het bedrijfslogo en verder niets. Blijft bewust een
/// achtergrondtekening — lage dekking, geen omranding, geen tekst — zodat hij de
/// hero-kaart eronder niet beconcurreert.
struct VandaagHeaderArt: View {
    /// Zongeel, lichter dan het signaaltoken `warm`: die kleur betekent in de app
    /// "let op" (lege dag, afwezigheid) en moet niet in een tekening opduiken.
    private let sunColor = BovexaTheme.Colors.sunYellow

    var body: some View {
        ZStack {
            // De zon staat ónder de berg in de stapel, zodat hij er half achter
            // wegzakt zoals in de mockup. Los ervóór hing hij als een bal in de
            // lucht en trok hij meer aandacht dan de kaart eronder.
            Circle()
                .fill(sunColor.opacity(0.9))
                .frame(width: 40, height: 40)
                .offset(x: 30, y: 2)

            Mountain()
                .fill(BovexaTheme.Colors.blue.opacity(0.10))
                .frame(width: 190, height: 52)
                .offset(y: 22)

            Image(systemName: "sparkle")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(BovexaTheme.Colors.white.opacity(0.95))
                .offset(x: -28, y: -10)

            Image(systemName: "sparkle")
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(BovexaTheme.Colors.white.opacity(0.85))
                .offset(x: -8, y: 10)

            Image(systemName: "sparkle")
                .font(.system(size: 7, weight: .medium))
                .foregroundStyle(BovexaTheme.Colors.white.opacity(0.8))
                .offset(x: 58, y: 6)
        }
        // Laag gehouden: hoger gaf een gat tussen de datum en de eerste kaart en
        // ging de tekening als een eigen blok lezen.
        .frame(width: 180, height: 62)
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Eén heuvel met een zachte piek links van het midden — twee ellipsen naast
/// elkaar lazen als banden in plaats van als landschap.
private struct Mountain: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.maxY))
        path.addCurve(
            to: CGPoint(x: rect.width * 0.42, y: rect.minY),
            control1: CGPoint(x: rect.width * 0.16, y: rect.maxY),
            control2: CGPoint(x: rect.width * 0.28, y: rect.minY)
        )
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY),
            control1: CGPoint(x: rect.width * 0.60, y: rect.minY),
            control2: CGPoint(x: rect.width * 0.74, y: rect.maxY)
        )
        path.closeSubpath()
        return path
    }
}

#Preview {
    ZStack {
        AppBackground()
        VandaagHeaderArt()
    }
}
