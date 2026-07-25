import SwiftUI

struct StatTile: View {
    let value: String
    let label: String
    /// Optionele bijregel, bv. "1 afwezigheid" naast het aantal afspraken.
    var note: String?

    var body: some View {
        VStack(alignment: .leading, spacing: BovexaTheme.Space.xs) {
            Text(value)
                .font(BovexaTheme.TypeStyle.statNumber)
                .foregroundStyle(BovexaTheme.Colors.ink)
            Text(label)
                .font(BovexaTheme.TypeStyle.statLabel)
                .foregroundStyle(BovexaTheme.Colors.inkSoft)
            if let note {
                Text(note)
                    .font(BovexaTheme.TypeStyle.caption)
                    .foregroundStyle(BovexaTheme.categoryColor(for: .afwezig))
            }
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
