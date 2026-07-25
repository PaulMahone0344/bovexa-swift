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

    /// v3: vijf duidelijk verschillende silhouetten (zon, kalender, lijst,
    /// gebouw, persoon). De v2-set had twee persoon-iconen en twee cirkels,
    /// waardoor de tabs op klein formaat op elkaar leken.
    ///
    /// v4: `building.2.fill` en `checklist` eruit. Het gebouw was een blok van
    /// massieve rechthoeken en de checklist een vinkje plus een rondje plus twee
    /// streepjes — samen te veel detail op tabbalk-formaat. Koffer en vinkje in
    /// een cirkel hebben één duidelijke vorm.
    var icon: String {
        switch self {
        case .vandaag: return "sun.horizon.fill"
        case .agenda: return "calendar"
        case .dagtaken: return "checkmark.circle.fill"
        case .bedrijf: return "briefcase.fill"
        case .profiel: return "person.fill"
        }
    }
}

/// Tabbalk met 5 tabs. Vandaag/Agenda/Dagtaken hebben hun echte scherm;
/// Bedrijf/Profiel tonen tot latere milestones een "Komt binnenkort".
/// v2 (Liquid Glass restyle): native `TabView` met de nieuwe `Tab(_:systemImage:)`-
/// syntax i.p.v. de custom `FloatingTabBar` — dat geeft systeemeigen glas-chrome
/// en ondersteunt `.tabBarMinimizeBehavior`. Zie DESIGN-NOTES.md.
struct RootTabView: View {
    @State private var selected: BovexaTab = .vandaag

    var body: some View {
        // Elk schermtype (VandaagView/AgendaView/ComingSoonView/ProfielPlaceholderView)
        // bevat al zijn eigen `AppBackground()` — dus geen extra achtergrond hier
        // omheen zetten, dat zou 'm dubbel tekenen.
        TabView(selection: $selected) {
            Tab(BovexaTab.vandaag.label, systemImage: BovexaTab.vandaag.icon, value: .vandaag) {
                VandaagView()
            }

            Tab(BovexaTab.agenda.label, systemImage: BovexaTab.agenda.icon, value: .agenda) {
                AgendaView()
            }

            Tab(BovexaTab.dagtaken.label, systemImage: BovexaTab.dagtaken.icon, value: .dagtaken) {
                DagtakenView()
            }

            Tab(BovexaTab.bedrijf.label, systemImage: BovexaTab.bedrijf.icon, value: .bedrijf) {
                BedrijfView()
            }

            Tab(BovexaTab.profiel.label, systemImage: BovexaTab.profiel.icon, value: .profiel) {
                ProfielPlaceholderView()
            }
        }
        .tint(BovexaTheme.Colors.teal)
        .tabBarMinimizeBehavior(.onScrollDown)
    }
}

#Preview {
    RootTabView()
}
