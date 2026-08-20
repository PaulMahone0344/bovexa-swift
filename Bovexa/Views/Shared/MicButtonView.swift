import SwiftUI

/// Microfoon-knop voor dicteren — pulseert tijdens luisteren. Gebruikt in de plan-pill
/// (Agenda) en de planner-composer.
struct MicButtonView: View {
    let listening: Bool
    var size: CGFloat = 40
    let onTap: () -> Void

    @State private var pulse = false

    var body: some View {
        Button(action: onTap) {
            Image(systemName: listening ? "mic.fill" : "mic")
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(listening ? BovexaTheme.Colors.white : BovexaTheme.Colors.accent)
                .frame(width: size, height: size)
                .background(listening ? AnyShapeStyle(BovexaTheme.Colors.danger) : AnyShapeStyle(BovexaTheme.Colors.glass))
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(listening ? Color.clear : BovexaTheme.Colors.edge, lineWidth: 1))
                .scaleEffect(listening && pulse ? 1.12 : 1.0)
                // Tekening blijft `size` (34 in de composer, 36 in de pill), het
                // raakvlak wordt 44 (M11 patroon B).
                .minTapTarget()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(listening ? "Stop dicteren" : "Dicteren")
        .onChange(of: listening) { _, isListening in
            if isListening {
                withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { pulse = true }
            } else {
                pulse = false
            }
        }
    }
}

#Preview {
    ZStack {
        AppBackground()
        HStack(spacing: BovexaTheme.Space.lg) {
            MicButtonView(listening: false) {}
            MicButtonView(listening: true) {}
        }
    }
}
