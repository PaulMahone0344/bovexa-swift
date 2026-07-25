import SwiftUI

/// Plan-pill onderaan Agenda (altijd zichtbaar): tekstveld + AI-knop. Geport uit de
/// plan-pill in agenda.tsx (RN) — mic-knop komt in plak 4.
struct PlannerEntryPillView: View {
    @Binding var text: String
    let onSubmit: () -> Void
    let onOpenPlanner: () -> Void

    @State private var pulse = false

    var body: some View {
        HStack(spacing: BovexaTheme.Space.sm) {
            TextField("Typ of spreek een planning", text: $text)
                .font(BovexaTheme.TypeStyle.subheadline)
                .submitLabel(.send)
                .onSubmit(onSubmit)

            Button {
                Haptics.selection()
                onOpenPlanner()
            } label: {
                Image(systemName: "sparkles")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(BovexaTheme.Colors.white)
                    .frame(width: 40, height: 40)
                    .background(LinearGradient(colors: BovexaTheme.Gradients.teal, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .clipShape(Circle())
                    .scaleEffect(pulse ? 1.08 : 1.0)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
        }
        .padding(.horizontal, BovexaTheme.Space.md)
        .padding(.vertical, BovexaTheme.Space.sm)
        .background(BovexaTheme.Colors.glass)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(BovexaTheme.Colors.edge, lineWidth: 1))
        .shadow(color: BovexaTheme.Shadow.softColor.opacity(0.16), radius: 16, x: 0, y: 9)
        .padding(.horizontal, BovexaTheme.Space.lg)
        .padding(.bottom, BovexaTheme.Space.sm)
    }
}

#Preview {
    ZStack {
        AppBackground()
        VStack {
            Spacer()
            PlannerEntryPillView(text: .constant(""), onSubmit: {}, onOpenPlanner: {})
        }
    }
}
