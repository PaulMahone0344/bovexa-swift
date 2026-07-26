import SwiftUI

/// Aantikbare antwoord-chips onder een AI-vraag. Geport uit QuickReplyChips.tsx.
struct QuickReplyChipsView: View {
    let options: [String]
    var disabled: Bool = false
    let onSelect: (String) -> Void

    var body: some View {
        if !options.isEmpty {
            FlowLayout(spacing: BovexaTheme.Space.sm) {
                ForEach(options, id: \.self) { option in
                    Button {
                        Haptics.selection()
                        onSelect(option)
                    } label: {
                        Text(option)
                            .font(BovexaTheme.TypeStyle.subheadline.weight(.bold))
                            .foregroundStyle(BovexaTheme.Colors.accent)
                            .padding(.horizontal, BovexaTheme.Space.md)
                            .padding(.vertical, BovexaTheme.Space.sm)
                            .background(BovexaTheme.Colors.glassStrong)
                            .clipShape(Capsule())
                            .overlay(Capsule().strokeBorder(BovexaTheme.Colors.blue, lineWidth: 1))
                    }
                    .disabled(disabled)
                    .opacity(disabled ? 0.5 : 1)
                }
            }
        }
    }
}

#Preview {
    ZStack {
        AppBackground()
        QuickReplyChipsView(options: ["Morgen", "Overmorgen", "Volgende week"]) { _ in }
            .padding()
    }
}
