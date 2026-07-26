import Foundation

/// Welke tab open staat. Ligt buiten RootTabView zodat een kaart op Vandaag naar
/// een andere tab kan sturen — de dagtaken-kaart doet dat.
///
/// Eerder hield RootTabView dit in een eigen @State; een scherm eronder kon er
/// dan niet bij zonder een closure door drie lagen te geven.
@MainActor
final class TabRouter: ObservableObject {
    @Published var selected: BovexaTab = .vandaag

    func open(_ tab: BovexaTab) {
        selected = tab
    }
}
