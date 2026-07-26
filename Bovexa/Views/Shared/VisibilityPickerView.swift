import SwiftUI

/// "Wie kan dit zien?" — twee segmenten: Privé of het bedrijf (echte naam, 1 regel met
/// ellipsis bij lange namen). De caller normaliseert oude waarden (team/manager/busy/
/// people) naar "company" vóórdat ze hier binnenkomen (valkuil D) — deze view kent
/// alleen "private"/"company".
struct VisibilityPickerView: View {
    let value: String
    let companyName: String
    var disabled: Bool = false
    let onChange: (String) -> Void

    private var segments: [(value: String, label: String, icon: String)] {
        [("private", "Privé", "lock"), ("company", companyName, "briefcase")]
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BovexaTheme.Space.md) {
                Text("Wie kan dit zien?")
                    .font(BovexaTheme.TypeStyle.caption.weight(.bold))
                    .foregroundStyle(BovexaTheme.Colors.accent)
                    .textCase(.uppercase)
                    .tracking(0.3)

                HStack(spacing: BovexaTheme.Space.sm) {
                    ForEach(segments, id: \.value) { segment in
                        segmentButton(segment)
                    }
                }
            }
        }
    }

    private func segmentButton(_ segment: (value: String, label: String, icon: String)) -> some View {
        let active = value == segment.value
        return Button {
            Haptics.selection()
            withAnimation(.snappy) { onChange(segment.value) }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: segment.icon)
                    .font(.system(size: 14, weight: .medium))
                Text(segment.label)
                    .font(BovexaTheme.TypeStyle.subheadline.weight(.bold))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .foregroundStyle(active ? BovexaTheme.Colors.white : BovexaTheme.Colors.muted)
            .frame(maxWidth: .infinity, minHeight: 42)
            .background(active ? BovexaTheme.Colors.blueDeep : BovexaTheme.Colors.glass)
            .overlay(
                RoundedRectangle(cornerRadius: BovexaTheme.Radius.md, style: .continuous)
                    .strokeBorder(active ? BovexaTheme.Colors.blueDeep : BovexaTheme.Colors.edge, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: BovexaTheme.Radius.md, style: .continuous))
        }
        .disabled(disabled)
    }
}

#Preview {
    ZStack {
        AppBackground()
        VisibilityPickerView(value: "company", companyName: "Bovexa") { _ in }
            .padding()
    }
}
