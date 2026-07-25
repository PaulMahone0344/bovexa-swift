import SwiftUI

/// Plan-ingang onderaan Agenda: standaard één ronde AI-knop, die uitklapt naar
/// tekstveld + microfoon zodra je hem aantikt. Geport uit de plan-pill in
/// agenda.tsx (RN), maar daar stond de balk altijd open — op een maandoverzicht
/// kost dat permanent ongeveer een kalenderweek aan ruimte.
struct PlannerEntryPillView: View {
    @Binding var text: String
    var micAvailable: Bool = false
    var listening: Bool = false
    var onMicTap: () -> Void = {}
    let onSubmit: () -> Void
    let onOpenPlanner: () -> Void

    @State private var expanded = false
    @FocusState private var fieldFocused: Bool

    var body: some View {
        Group {
            if expanded {
                fullPill
            } else {
                collapsedButton
            }
        }
        .animation(.snappy(duration: 0.25), value: expanded)
        .onChange(of: listening) { _, isListening in
            // Dicteren start ook vanuit ingeklapte staat; klap dan open zodat
            // je het transcript ziet groeien.
            if isListening { expanded = true }
        }
    }

    /// Ingeklapt: alleen de AI-knop, rechts uitgelijnd.
    private var collapsedButton: some View {
        HStack {
            Spacer()
            Button {
                Haptics.selection()
                expanded = true
                fieldFocused = true
            } label: {
                sparkleCircle(size: 52, icon: 20)
            }
            .accessibilityLabel("Planning typen of inspreken")
        }
        .padding(.horizontal, BovexaTheme.Space.lg)
        .padding(.bottom, BovexaTheme.Space.sm)
    }

    private func sparkleCircle(size: CGFloat, icon: CGFloat) -> some View {
        Image(systemName: "sparkles")
            .font(.system(size: icon, weight: .semibold))
            .foregroundStyle(BovexaTheme.Colors.white)
            .frame(width: size, height: size)
            .background(LinearGradient(colors: BovexaTheme.Gradients.teal, startPoint: .topLeading, endPoint: .bottomTrailing))
            .clipShape(Circle())
            .shadow(color: BovexaTheme.Shadow.tealGlowColor.opacity(0.28), radius: 10, x: 0, y: 5)
    }

    private var fullPill: some View {
        HStack(spacing: BovexaTheme.Space.sm) {
            Button {
                fieldFocused = false
                expanded = false
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(BovexaTheme.Colors.muted)
            }
            .accessibilityLabel("Invoer sluiten")

            TextField("Typ of spreek een planning", text: $text)
                .font(BovexaTheme.TypeStyle.subheadline)
                .submitLabel(.send)
                .focused($fieldFocused)
                .onSubmit {
                    onSubmit()
                    expanded = false
                }

            if micAvailable {
                MicButtonView(listening: listening, size: 36, onTap: onMicTap)
            }

            Button {
                Haptics.selection()
                onOpenPlanner()
                expanded = false
            } label: {
                sparkleCircle(size: 40, icon: 17)
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
