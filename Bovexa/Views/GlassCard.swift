import SwiftUI

/// Glaskaart v2 (Liquid Glass restyle): echt systeemglas via `.glassEffect`
/// i.p.v. de v1 geschilderde verloop-vulling. Publieke API (radius/padding/
/// content) is ongewijzigd zodat bestaande call-sites door de hele app blijven
/// werken — zie DESIGN-NOTES.md.
struct GlassCard<Content: View>: View {
    var radius: CGFloat = BovexaTheme.Radius.lg
    var padding: CGFloat = BovexaTheme.Space.lg
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .glassEffect(
                .regular,
                in: RoundedRectangle(cornerRadius: radius, style: .continuous)
            )
            .shadow(
                color: BovexaTheme.Shadow.softColor.opacity(BovexaTheme.Shadow.softOpacity),
                radius: BovexaTheme.Shadow.softRadius,
                x: 0,
                y: BovexaTheme.Shadow.softOffsetY
            )
    }
}

#Preview {
    ZStack {
        AppBackground()
        GlassCard {
            Text("Glaskaart")
                .foregroundStyle(BovexaTheme.Colors.ink)
        }
        .padding()
    }
}
