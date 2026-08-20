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
            .background(LinearGradient(colors: BovexaTheme.Gradients.blue, startPoint: .topLeading, endPoint: .bottomTrailing))
            .clipShape(Circle())
            .shadow(color: BovexaTheme.Shadow.blueGlowColor.opacity(0.28), radius: 10, x: 0, y: 5)
    }

    private var fullPill: some View {
        HStack(spacing: BovexaTheme.Space.sm) {
            Button {
                fieldFocused = false
                expanded = false
            } label: {
                // Enige manier om de pill te sluiten zonder te versturen; het
                // raakvlak was 9x15pt (M11 patroon B).
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(BovexaTheme.Colors.muted)
                    .minTapTarget()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Invoer sluiten")

            TextField("Typ of spreek een planning", text: $text)
                .font(BovexaTheme.TypeStyle.subheadline)
                .submitLabel(.send)
                .keyboardDone(focused: $fieldFocused)
                .onSubmit {
                    // Eerst focus loslaten: de pill klapt hierna in en een veld
                    // dat nog focus heeft terwijl het uit de hiërarchie verdwijnt
                    // laat het toetsenbord hangen.
                    fieldFocused = false
                    onSubmit()
                    expanded = false
                }

            if micAvailable {
                MicButtonView(listening: listening, size: 36, onTap: onMicTap)
            }

            Button {
                Haptics.selection()
                // Zelfde volgorde als onSubmit: zonder dit blijft het toetsenbord
                // over de planner-sheet heen staan.
                fieldFocused = false
                onOpenPlanner()
                expanded = false
            } label: {
                sparkleCircle(size: 40, icon: 17).minTapTarget()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Planner openen")
        }
        .padding(.horizontal, BovexaTheme.Space.md)
        // Van sm (10) naar 8: de knoppen in de pill dragen sinds M11 hun eigen
        // 44pt raakvlak in plaats van 36-40, dus zonder deze correctie werd de
        // pill hoger dan de 60pt waarop de rest is afgeregeld. 44 + 2×8 = 60.
        .padding(.vertical, 8)
        .background(BovexaTheme.Colors.floatingSurface)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(BovexaTheme.Colors.edge, lineWidth: 1))
        // Zwaardere schaduw dan een gewone kaart: de pill zweeft boven de
        // kalender en moet daar los van staan nu hij dekkend is.
        .shadow(color: BovexaTheme.Shadow.softColor.opacity(0.28), radius: 18, x: 0, y: 10)
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
