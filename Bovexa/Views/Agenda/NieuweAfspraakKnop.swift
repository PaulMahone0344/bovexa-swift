import SwiftUI

/// Zwevende knop onderaan de Agenda: één ingang naar een nieuwe afspraak.
///
/// Hier stond eerst een uitklapbare balk waarin je meteen een zin kon typen of
/// inspreken. Die zin moest daarna in de keuze-sheet herhaald worden om duidelijk
/// te maken wat er meeging, en dat las rommelig. Nu vraagt de knop eerst wat je
/// wilt; typen of dicteren doe je in de route die je kiest — het formulier of de
/// AI-planner, allebei met een eigen veld.
struct NieuweAfspraakKnop: View {
    let onTap: () -> Void

    var body: some View {
        HStack {
            Spacer()
            Button {
                Haptics.selection()
                onTap()
            } label: {
                HStack(spacing: BovexaTheme.Space.xs) {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .bold))
                    Text("Nieuwe afspraak")
                        .font(BovexaTheme.TypeStyle.subheadline.weight(.semibold))
                }
                .foregroundStyle(BovexaTheme.Colors.white)
                .padding(.horizontal, BovexaTheme.Space.lg)
                .frame(height: 52)
                .background(LinearGradient(colors: BovexaTheme.Gradients.blue, startPoint: .topLeading, endPoint: .bottomTrailing))
                .clipShape(Capsule())
                // Zwaardere schaduw dan een gewone kaart: de knop zweeft boven de
                // kalender en moet daar los van staan.
                .shadow(color: BovexaTheme.Shadow.blueGlowColor.opacity(0.28), radius: 12, x: 0, y: 6)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Nieuwe afspraak")
        }
        .padding(.horizontal, BovexaTheme.Space.lg)
        .padding(.bottom, BovexaTheme.Space.sm)
    }
}

#Preview {
    ZStack {
        AppBackground()
        VStack {
            Spacer()
            NieuweAfspraakKnop(onTap: {})
        }
    }
}
