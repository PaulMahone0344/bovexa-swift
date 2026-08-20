import SwiftUI

/// Herinnering-chips: Geen / 15 min vooraf / 1 uur vooraf / 1 dag vooraf.
struct ReminderChipsView: View {
    @Binding var minutesBefore: Int
    var disabled: Bool = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: BovexaTheme.Space.xs) {
                ForEach(ReminderOption.all) { option in
                    chip(option)
                }
            }
        }
    }

    private func chip(_ option: ReminderOption) -> some View {
        let active = minutesBefore == option.minutes
        return Button {
            Haptics.selection()
            withAnimation(.snappy) { minutesBefore = option.minutes }
        } label: {
            Text(option.label)
                .font(BovexaTheme.TypeStyle.subheadline.weight(.bold))
                .foregroundStyle(active ? BovexaTheme.Colors.white : BovexaTheme.Colors.muted)
                .padding(.horizontal, BovexaTheme.Space.md)
                .frame(minHeight: 44)
                .background(active ? BovexaTheme.Colors.blueDeep : BovexaTheme.Colors.glass)
                .clipShape(Capsule())
                .overlay(
                    Capsule().strokeBorder(active ? BovexaTheme.Colors.blueDeep : BovexaTheme.Colors.edge, lineWidth: 1)
                )
        }
        .disabled(disabled)
    }
}

#Preview {
    ZStack {
        AppBackground()
        ReminderChipsView(minutesBefore: .constant(15))
            .padding()
    }
}
