import SwiftUI

struct StatTile: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: BovexaTheme.Space.xs) {
            Text(value)
                .font(BovexaTheme.TypeStyle.statNumber)
                .foregroundStyle(BovexaTheme.Colors.ink)
            Text(label)
                .font(BovexaTheme.TypeStyle.statLabel)
                .foregroundStyle(BovexaTheme.Colors.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    ZStack {
        AppBackground()
        GlassCard {
            HStack {
                StatTile(value: "3", label: "afspraken")
                StatTile(value: "5,5 uur", label: "geplande uren")
            }
        }
        .padding()
    }
}
