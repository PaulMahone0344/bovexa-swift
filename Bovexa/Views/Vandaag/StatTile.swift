import SwiftUI

struct StatTile: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: BovexaTheme.Space.xs) {
            Text(value)
                .font(.system(size: BovexaTheme.TypeScale.h2, weight: .bold))
                .foregroundStyle(BovexaTheme.Colors.ink)
            Text(label)
                .font(.system(size: BovexaTheme.TypeScale.small))
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
