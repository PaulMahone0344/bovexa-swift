import SwiftUI

/// Donkere gradient-achtergrond met zachte teal orbs, achter elk scherm.
struct AppBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: BovexaTheme.Gradients.background,
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            GeometryReader { geo in
                Circle()
                    .fill(BovexaTheme.Colors.teal.opacity(0.16))
                    .frame(width: geo.size.width * 0.9)
                    .blur(radius: 90)
                    .offset(x: -geo.size.width * 0.3, y: -geo.size.height * 0.15)

                Circle()
                    .fill(BovexaTheme.Colors.accent.opacity(0.12))
                    .frame(width: geo.size.width * 0.7)
                    .blur(radius: 90)
                    .offset(x: geo.size.width * 0.4, y: geo.size.height * 0.55)
            }
            .ignoresSafeArea()
        }
    }
}

#Preview {
    AppBackground()
}
