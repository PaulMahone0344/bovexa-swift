import SwiftUI

enum BovexaTab: String, CaseIterable, Identifiable {
    case vandaag, agenda, dagtaken, bedrijf, profiel

    var id: String { rawValue }

    var label: String {
        switch self {
        case .vandaag: return "Vandaag"
        case .agenda: return "Agenda"
        case .dagtaken: return "Dagtaken"
        case .bedrijf: return "Bedrijf"
        case .profiel: return "Profiel"
        }
    }

    var icon: String {
        switch self {
        case .vandaag: return "sun.max"
        case .agenda: return "calendar"
        case .dagtaken: return "checklist"
        case .bedrijf: return "building.2"
        case .profiel: return "person.crop.circle"
        }
    }
}

/// Tabbalk met 5 tabs. Vandaag/Agenda krijgen hun echte scherm in plak 4/5;
/// Dagtaken/Bedrijf/Profiel tonen tot latere milestones een "Komt binnenkort".
struct RootTabView: View {
    @State private var selected: BovexaTab = .vandaag

    var body: some View {
        ZStack(alignment: .bottom) {
            AppBackground()

            Group {
                switch selected {
                case .vandaag:
                    ComingSoonView(title: "Vandaag")
                case .agenda:
                    ComingSoonView(title: "Agenda")
                case .dagtaken:
                    ComingSoonView(title: "Dagtaken")
                case .bedrijf:
                    ComingSoonView(title: "Bedrijf")
                case .profiel:
                    ComingSoonView(title: "Profiel")
                }
            }

            FloatingTabBar(selected: $selected)
                .padding(.horizontal, BovexaTheme.Space.lg)
                .padding(.bottom, BovexaTheme.Space.sm)
        }
    }
}

/// Zwevende glazen tabbalk onderin.
private struct FloatingTabBar: View {
    @Binding var selected: BovexaTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(BovexaTab.allCases) { tab in
                Button {
                    selected = tab
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 20, weight: .semibold))
                        Text(tab.label)
                            .font(.system(size: BovexaTheme.TypeScale.tiny, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(selected == tab ? BovexaTheme.Colors.teal : BovexaTheme.Colors.navInactive)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, BovexaTheme.Space.sm)
        .background(
            BovexaTheme.Colors.navSurface.opacity(0.92)
        )
        .overlay(
            RoundedRectangle(cornerRadius: BovexaTheme.Radius.pill, style: .continuous)
                .strokeBorder(BovexaTheme.Colors.navBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: BovexaTheme.Radius.pill, style: .continuous))
        .shadow(
            color: BovexaTheme.Shadow.softColor.opacity(BovexaTheme.Shadow.softOpacity),
            radius: BovexaTheme.Shadow.softRadius,
            x: 0,
            y: BovexaTheme.Shadow.softOffsetY
        )
    }
}

#Preview {
    RootTabView()
}
