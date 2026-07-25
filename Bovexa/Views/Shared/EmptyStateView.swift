import SwiftUI

/// Lege staat: icoon + tekst, native stijl. Herbruikbaar op elk scherm met een
/// leeg-resultaat (geen afspraken, geen zoekresultaat, geen collega's, ...).
struct EmptyStateView: View {
    let systemImage: String
    let text: String

    var body: some View {
        VStack(spacing: BovexaTheme.Space.sm) {
            Image(systemName: systemImage)
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(BovexaTheme.Colors.muted)
            Text(text)
                .font(BovexaTheme.TypeStyle.subheadline)
                .foregroundStyle(BovexaTheme.Colors.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, BovexaTheme.Space.lg)
    }
}

#Preview {
    ZStack {
        AppBackground()
        EmptyStateView(systemImage: "calendar", text: "Nog niks gepland vandaag…")
            .padding()
    }
}
