import SwiftUI

/// Knopstijlen v2 (Liquid Glass restyle): dunne wrappers rondom de systeem-
/// glasknopstijlen (`.glassProminent` / `.glass`) zodat de teal-merkkleur als
/// tint meegaat. Conformeren aan `PrimitiveButtonStyle` (niet `ButtonStyle`):
/// alleen `PrimitiveButtonStyleConfiguration` heeft een `Button(_:)`-
/// initializer waarmee de systeemstijl binnen `makeBody` opnieuw toegepast
/// kan worden — `.buttonStyle(...)` op `configuration.label` (een gewone
/// `View`, geen `Button`) heeft geen effect, dus een `ButtonStyle`-conformance
/// zou dit niet compileren/werken. Nog niet toegepast op bestaande schermen —
/// dat is plak 2-4. Zie DESIGN-NOTES.md.
struct GlassProminentButtonStyle: PrimitiveButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(configuration)
            .buttonStyle(.glassProminent)
            .tint(BovexaTheme.Glass.tint)
    }
}

/// Secundaire glasknop: neutraal systeemglas zonder teal-tint, voor knoppen
/// die niet de primaire actie op het scherm zijn.
struct GlassSecondaryButtonStyle: PrimitiveButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(configuration)
            .buttonStyle(.glass)
    }
}

extension PrimitiveButtonStyle where Self == GlassProminentButtonStyle {
    static var glassProminentBrand: GlassProminentButtonStyle { GlassProminentButtonStyle() }
}

extension PrimitiveButtonStyle where Self == GlassSecondaryButtonStyle {
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
        }
        .padding()
    }
}
