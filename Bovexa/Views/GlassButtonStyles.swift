import SwiftUI

/// Knopstijlen v2 (Liquid Glass restyle): dunne wrappers rondom de systeem-
/// glasknopstijlen zodat de merkkleur als tint meegaat. Conformeren aan
/// `PrimitiveButtonStyle` (niet `ButtonStyle`): alleen
/// `PrimitiveButtonStyleConfiguration` heeft een `Button(_:)`-initializer waarmee
/// de systeemstijl binnen `makeBody` opnieuw toegepast kan worden.
/// Primaire knop: gevulde merkpil met witte tekst.
///
/// Was de systeem-glasknop met merktint. Die zag er ingeschakeld goed uit, maar
/// uitgeschakeld maakte het systeem er grijs op grijs van — "Toevoegen" op
/// Dagtaken was letterlijk niet te lezen zolang het tekstvak leeg was, terwijl
/// juist die knop vertelt wat je nog moet doen. De uitgeschakelde staat is nu
/// een lichtere merkkleur met witte tekst: duidelijk minder nadruk, maar wel
/// leesbaar.
struct GlassProminentButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(BovexaTheme.TypeStyle.subheadline.weight(.semibold))
            .foregroundStyle(BovexaTheme.Colors.white.opacity(isEnabled ? 1 : 0.85))
            .padding(.horizontal, BovexaTheme.Space.lg)
            .frame(minHeight: 42)
            .background(
                Capsule().fill(
                    LinearGradient(
                        colors: isEnabled ? BovexaTheme.Gradients.blue : BovexaTheme.Gradients.blueSoft,
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .opacity(isEnabled ? 1 : 0.45)
            )
            .shadow(
                color: BovexaTheme.Shadow.blueGlowColor.opacity(isEnabled ? 0.28 : 0),
                radius: 8, y: 4
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
            .contentShape(Capsule())
    }
}

/// Secundaire knop: dekkende parelwitte pil met een dunne accentrand.
///
/// Was tot 26 juli kaal systeemglas (`.buttonStyle(.glass)`). Op een lichte
/// glaskaart — en zeker op een hero-kaart — was daar niets van te zien: je zag
/// blauwe tekst zweven zonder knopvorm, wat las als een link uit 1999. Dekkend
/// wit geeft de knop een rand tegen de kaart eronder; de accentrand en de lichte
/// schaduw maken duidelijk dat je erop kunt tikken.
///
/// `tint` bestaat sinds M11. De stijl zette de accentkleur en het lettertype hard
/// op het label en overschreef daarmee elke `.foregroundStyle(danger)` of
/// `.tint(danger)` die de aanroeper erbuiten zette: Uitloggen, Verwijderen en
/// Wissen renderden gewoon blauw, terwijl de code rood bedoelde. Voor die drie
/// bestaat nu `.glassSecondaryDanger`.
struct GlassSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    var tint: Color = BovexaTheme.Colors.accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(BovexaTheme.TypeStyle.subheadline.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, BovexaTheme.Space.md)
            .frame(minHeight: 38)
            .background(BovexaTheme.Colors.floatingSurface, in: Capsule())
            .overlay(
                Capsule().strokeBorder(tint.opacity(0.22), lineWidth: 1)
            )
            .shadow(color: BovexaTheme.Shadow.softColor.opacity(0.18), radius: 6, y: 3)
            .opacity(isEnabled ? 1 : 0.45)
            // Ingedrukt iets kleiner en doffer: zonder terugkoppeling voelt een
            // dekkende pil dood aan.
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
            .contentShape(Capsule())
    }
}

extension ButtonStyle where Self == GlassProminentButtonStyle {
    static var glassProminentBrand: GlassProminentButtonStyle { GlassProminentButtonStyle() }
}

extension ButtonStyle where Self == GlassSecondaryButtonStyle {
    static var glassSecondaryBrand: GlassSecondaryButtonStyle { GlassSecondaryButtonStyle() }

    /// Zelfde pil, maar tekst en rand in `danger` — voor Uitloggen, Verwijderen
    /// en Wissen. Alleen voor acties die iets weggooien of afsluiten; niet als
    /// algemene "let op"-kleur.
    static var glassSecondaryDanger: GlassSecondaryButtonStyle {
        GlassSecondaryButtonStyle(tint: BovexaTheme.Colors.danger)
    }
}

#Preview {
    ZStack {
        AppBackground()
        VStack(spacing: BovexaTheme.Space.lg) {
            Button("Primair") {}
                .buttonStyle(.glassProminentBrand)
            Button("Secundair") {}
                .buttonStyle(.glassSecondaryBrand)
            Button {} label: { Text("Uitloggen").frame(maxWidth: .infinity) }
                .buttonStyle(.glassSecondaryDanger)
            Button("Uitgeschakeld") {}
                .buttonStyle(.glassSecondaryBrand)
                .disabled(true)
        }
        .padding()
    }
}
