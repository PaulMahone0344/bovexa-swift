import SwiftUI

/// Knopstijlen v2 (Liquid Glass restyle): dunne wrappers rondom de systeem-
/// glasknopstijlen zodat de merkkleur als tint meegaat. Conformeren aan
/// `PrimitiveButtonStyle` (niet `ButtonStyle`): alleen
/// `PrimitiveButtonStyleConfiguration` heeft een `Button(_:)`-initializer waarmee
/// de systeemstijl binnen `makeBody` opnieuw toegepast kan worden.
struct GlassProminentButtonStyle: PrimitiveButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(configuration)
            .buttonStyle(.glassProminent)
            .tint(BovexaTheme.Glass.tint)
    }
}

/// Secundaire knop: dekkende parelwitte pil met een dunne accentrand.
///
/// Was tot 26 juli kaal systeemglas (`.buttonStyle(.glass)`). Op een lichte
/// glaskaart — en zeker op een hero-kaart — was daar niets van te zien: je zag
/// blauwe tekst zweven zonder knopvorm, wat las als een link uit 1999. Dekkend
/// wit geeft de knop een rand tegen de kaart eronder; de accentrand en de lichte
/// schaduw maken duidelijk dat je erop kunt tikken.
struct GlassSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(BovexaTheme.TypeStyle.subheadline.weight(.semibold))
            .foregroundStyle(BovexaTheme.Colors.accent)
            .padding(.horizontal, BovexaTheme.Space.md)
            .frame(minHeight: 38)
            .background(BovexaTheme.Colors.floatingSurface, in: Capsule())
            .overlay(
                Capsule().strokeBorder(BovexaTheme.Colors.accent.opacity(0.22), lineWidth: 1)
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

extension PrimitiveButtonStyle where Self == GlassProminentButtonStyle {
    static var glassProminentBrand: GlassProminentButtonStyle { GlassProminentButtonStyle() }
}

extension ButtonStyle where Self == GlassSecondaryButtonStyle {
    static var glassSecondaryBrand: GlassSecondaryButtonStyle { GlassSecondaryButtonStyle() }
}

#Preview {
    ZStack {
        AppBackground()
        VStack(spacing: BovexaTheme.Space.lg) {
            Button("Primair") {}
                .buttonStyle(.glassProminentBrand)
            Button("Secundair") {}
                .buttonStyle(.glassSecondaryBrand)
            Button("Uitgeschakeld") {}
                .buttonStyle(.glassSecondaryBrand)
                .disabled(true)
        }
        .padding()
    }
}
