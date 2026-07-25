import Testing
import Foundation
@testable import Bovexa

@MainActor
struct SearchViewModelTests {
    init() {
        URLProtocolStub.requestHandler = nil
    }

    @Test func loadPopulatesEventsAndQueryFiltersResults() async {
        URLProtocolStub.requestHandler = { _ in
            let json = """
            {"items":[
              {"id":"a","owner":"u1","title":"Tandarts","start":"2026-08-03 09:00:00.000Z","all_day":false},
              {"id":"b","owner":"u1","title":"Kapper","start":"2026-08-04 09:00:00.000Z","all_day":false}
            ],"page":1,"perPage":200,"totalItems":2,"totalPages":1}
            """.data(using: .utf8)!
            return (200, json)
        }
        let repository = EventRepository(client: PBClient(session: URLProtocolStub.makeSession()))
        let viewModel = SearchViewModel(repository: repository)

        await viewModel.load(userId: "u1", orgId: nil, token: "tok")
        #expect(viewModel.results.isEmpty) // lege query → geen resultaten

        viewModel.query = "tandarts"
        #expect(viewModel.results.map(\.id) == ["a"])
    }

    @Test func networkFailureLeavesEmptyResultsInsteadOfCrashing() async {
        URLProtocolStub.requestHandler = nil
        let repository = EventRepository(client: PBClient(session: URLProtocolStub.makeSession()))
        let viewModel = SearchViewModel(repository: repository)
        await viewModel.load(userId: "u1", orgId: nil, token: "tok")
        viewModel.query = "iets"
        #expect(viewModel.results.isEmpty)
    }
}
