import SwiftUI

struct StatTile: View {
    let value: String
    let label: String
    /// Optionele bijregel, bv. "1 afwezigheid" naast het aantal afspraken.
    var note: String?
    /// Icoonrondje boven het cijfer. Zonder icoon zijn de twee tegels alleen aan
    /// hun onderschrift uit elkaar te houden — je moet dan lezen om te zien of je
    /// naar afspraken of naar uren kijkt.
    var systemImage: String?
    var tint: Color = BovexaTheme.Colors.blue

    var body: some View {
        // Icoon naast het cijfer in plaats van erboven (mockup 26 juli): boven
        // elkaar werd de tegel hoog en smal, en het cijfer — waar het om gaat —
        // zakte naar het midden van de kaart.
        HStack(alignment: .top, spacing: BovexaTheme.Space.sm) {
            if let systemImage {
                Circle()
                    .fill(tint.opacity(0.14))
                    .frame(width: 38, height: 38)
                    .overlay {
                        Image(systemName: systemImage)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(tint)
                    }
            }

            VStack(alignment: .leading, spacing: BovexaTheme.Space.xs) {
                Text(value)
                    .font(BovexaTheme.TypeStyle.statNumber)
                    .foregroundStyle(BovexaTheme.Colors.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(label)
                    .font(BovexaTheme.TypeStyle.statLabel)
                    .foregroundStyle(BovexaTheme.Colors.inkSoft)
                // Altijd een regel, ook zonder bijregel: zonder deze lege plek was
                // de tegel met "1 afwezigheid" hoger dan die ernaast en zakten de
                // twee cijfers naar verschillende hoogtes.
                Text(note ?? " ")
                    .font(BovexaTheme.TypeStyle.caption)
                    .foregroundStyle(BovexaTheme.categoryColor(for: .afwezig))
                    .opacity(note == nil ? 0 : 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

#Preview {
    ZStack {
        AppBackground()
        GlassCard {
            HStack {
                StatTile(value: "3", label: "afspraken", systemImage: "calendar")
                StatTile(
                    value: "5,5 uur", label: "geplande uren",
                    systemImage: "clock", tint: BovexaTheme.Colors.categoryGreen
                )
            }
        }
        .padding()
    }
}
