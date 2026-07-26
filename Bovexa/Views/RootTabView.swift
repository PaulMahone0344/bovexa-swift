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
    /// 26 juli: de drie gevulde iconen naar hun open variant, uit de icoonlijst
    /// van de opdrachtgever. Gevuld waren ze drie zware blokken naast de open
    /// kalender; de zon blijft gevuld, want die is anders een dun streepjesbeeld.
    var icon: String {
        switch self {
        case .vandaag: return "sun.horizon.fill"
        case .agenda: return "calendar"
        case .dagtaken: return "checkmark.circle"
        case .bedrijf: return "briefcase"
        case .profiel: return "person"
        }
    }
}

/// Tabbalk met 5 tabs. Vandaag/Agenda/Dagtaken hebben hun echte scherm;
/// Bedrijf/Profiel tonen tot latere milestones een "Komt binnenkort".
/// v2 (Liquid Glass restyle): native `TabView` met de nieuwe `Tab(_:systemImage:)`-
/// syntax i.p.v. de custom `FloatingTabBar` — dat geeft systeemeigen glas-chrome
/// en ondersteunt `.tabBarMinimizeBehavior`. Zie DESIGN-NOTES.md.
struct RootTabView: View {
    @EnvironmentObject private var router: TabRouter
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var joinCoordinator: JoinCoordinator

    private func outlineLabel(_ tab: BovexaTab) -> some View {
        Label {
            Text(tab.label)
        } icon: {
            Image(systemName: tab.icon)
                .environment(\.symbolVariants, .none)
        }
    }

    var body: some View {
        // Elk schermtype (VandaagView/AgendaView/DagtakenView/BedrijfView/ProfielView)
        // bevat al zijn eigen `AppBackground()` — dus geen extra achtergrond hier
        // omheen zetten, dat zou 'm dubbel tekenen.
        TabView(selection: $router.selected) {
            Tab(BovexaTab.vandaag.label, systemImage: BovexaTab.vandaag.icon, value: .vandaag) {
                VandaagView()
            }

            Tab(BovexaTab.agenda.label, systemImage: BovexaTab.agenda.icon, value: .agenda) {
                AgendaView()
            }

            // Deze drie via een eigen label: een tabbalk tekent elk symbool
            // standaard in zijn gevulde variant, dus "briefcase" kwam er alsnog
            // uit als "briefcase.fill". `symbolVariants(.none)` zet dat terug.
            Tab(value: .dagtaken) {
                DagtakenView()
            } label: {
                outlineLabel(BovexaTab.dagtaken)
            }

            Tab(value: .bedrijf) {
                BedrijfView()
            } label: {
                outlineLabel(BovexaTab.bedrijf)
            }

            Tab(value: .profiel) {
                ProfielView()
            } label: {
                outlineLabel(BovexaTab.profiel)
            }
        }
        .tint(BovexaTheme.Colors.blue)
        .tabBarMinimizeBehavior(.onScrollDown)
        .onChange(of: joinCoordinator.outcome) { _, outcome in
            guard outcome == .joined else { return }
            Haptics.success()
            router.open(.bedrijf)
            Task { await authStore.refreshCurrentUser() }
            joinCoordinator.reset()
        }
        .alert("Je hoort al bij een bedrijf.", isPresented: Binding(
            get: { joinCoordinator.outcome == .alreadyMember },
            set: { if !$0 { joinCoordinator.reset() } }
        )) {
            Button("Naar de agenda") { joinCoordinator.reset() }
        }
        .alert("Toetreden mislukt", isPresented: Binding(
            get: { if case .failed = joinCoordinator.outcome { return true }; return false },
            set: { if !$0 { joinCoordinator.reset() } }
        )) {
            Button("OK", role: .cancel) { joinCoordinator.reset() }
        } message: {
            if case .failed(let message) = joinCoordinator.outcome {
                Text(message)
            }
        }
    }
}

#Preview {
    RootTabView()
        .environmentObject(TabRouter())
        .environmentObject(AuthStore())
        .environmentObject(JoinCoordinator())
}
