import Foundation

/// Viewmodel voor het zoekscherm: eigen fetch (los van de Agenda-cache), lokaal filteren.
@MainActor
final class SearchViewModel: ObservableObject {
    @Published private(set) var allEvents: [AgendaEvent] = []
    @Published var query = ""

    private let repository: EventRepository

    init(repository: EventRepository = EventRepository()) {
        self.repository = repository
    }

    var results: [AgendaEvent] {
        EventSearch.search(allEvents, query: query)
    }

    func load(userId: String, orgId: String?, token: String) async {
        allEvents = (try? await repository.fetchAllEvents(userId: userId, orgId: orgId, token: token)) ?? []
    }
}
