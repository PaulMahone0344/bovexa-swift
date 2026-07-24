import SwiftUI

/// Glaskaart: verloop-vulling + rand + zachte schaduw, basis voor alle kaarten in de app.
struct GlassCard<Content: View>: View {
    var radius: CGFloat = BovexaTheme.Radius.lg
    var padding: CGFloat = BovexaTheme.Space.lg
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background(
                LinearGradient(
                    colors: BovexaTheme.Gradients.cardGlass,
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(BovexaTheme.Colors.edge, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
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
