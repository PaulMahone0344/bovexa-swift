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
            // De zon zakt half achter de heuvel; de heuvel is dekkend genoeg om
            // dat te laten zien (op 0.10 scheen de zon er dwars doorheen).
            Circle()
                .fill(sunColor.opacity(0.8))
                .frame(width: 34, height: 34)
                .offset(x: 26, y: -8)

            // Bodem van de heuvel valt precies op de framerand, zodat er geen
            // harde afsnijlijn meer onder hangt.
            Mountain()
                .fill(BovexaTheme.Colors.blue.opacity(0.16))
                .frame(width: 190, height: 50)
                .offset(y: 7)

            // Wolken zoals in de iPhone Weer-app: een grote half vóór de zon,
            // en een kleinere die los in de lucht hangt.
            Wolk()
                .opacity(0.95)
                .offset(x: 42, y: 6)

            Wolk()
                .scaleEffect(0.62)
                .opacity(0.7)
                .offset(x: -44, y: -14)

            Image(systemName: "sparkle")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(BovexaTheme.Colors.white.opacity(0.9))
                .offset(x: -8, y: 2)
        }
        // Laag gehouden: hoger gaf een gat tussen de datum en de eerste kaart en
        // ging de tekening als een eigen blok lezen.
        .frame(width: 180, height: 64)
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Bolwolkje in de stijl van het Weer-app-icoon: drie bollen op een afgeronde
/// basis. `compositingGroup` zorgt dat de dekking over het geheel gaat, anders
/// tekenen de overlappende bollen zich donkerder af.
private struct Wolk: View {
    var body: some View {
        ZStack {
            Circle().frame(width: 20).offset(x: -13, y: 3)
            Circle().frame(width: 28).offset(x: 0, y: -4)
            Circle().frame(width: 18).offset(x: 13, y: 4)
            Capsule().frame(width: 50, height: 16).offset(y: 6)
        }
        .foregroundStyle(BovexaTheme.Colors.white)
        .compositingGroup()
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
