import SwiftUI

/// Kop boven een blok op Vandaag: gekleurd icoonrondje met de titel ernaast.
///
/// De koppen "Tijdlijn" en "Deze week" waren losse regels tekst en verdwenen
/// tussen de kaarten; het rondje geeft ze een ankerpunt aan de linkerkant, in
/// lijn met de mockup van 26 juli.
struct SectionHeading: View {
    let title: String
    let systemImage: String
    var tint: Color = BovexaTheme.Colors.blue

    var body: some View {
        HStack(spacing: BovexaTheme.Space.sm) {
            Circle()
                .fill(tint)
                .frame(width: 30, height: 30)
                .overlay {
                    Image(systemName: systemImage)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(BovexaTheme.Colors.white)
                }
                .shadow(color: tint.opacity(0.25), radius: 6, y: 3)

            Text(title)
                .font(BovexaTheme.TypeStyle.headline)
                .foregroundStyle(BovexaTheme.Colors.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }
}

#Preview {
    ZStack {
        AppBackground()
        VStack(alignment: .leading, spacing: 20) {
            SectionHeading(title: "Tijdlijn", systemImage: "clock.fill")
            SectionHeading(title: "Deze week", systemImage: "chart.line.uptrend.xyaxis")
        }
        .padding()
    }
}
