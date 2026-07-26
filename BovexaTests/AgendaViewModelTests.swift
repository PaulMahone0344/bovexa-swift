import Testing
import Foundation
@testable import Bovexa

@MainActor
struct AgendaViewModelTests {
    init() {
        URLProtocolStub.requestHandler = nil
    }

    private func makeViewModel() -> AgendaViewModel {
        let repository = EventRepository(client: PBClient(session: URLProtocolStub.makeSession()))
        let labelRepository = LabelRepository(client: PBClient(session: URLProtocolStub.makeSession()))
        return AgendaViewModel(repository: repository, labelRepository: labelRepository)
    }

    private func stubEmptyEventsAndMembers(labelsJSON: String) {
        URLProtocolStub.requestHandler = { request in
            let path = request.url!.path
            if path.contains("agenda_labels") {
                return (200, labelsJSON.data(using: .utf8)!)
            }
            if path.contains("agenda_events") {
                let json = """
                {"items":[],"page":1,"perPage":200,"totalItems":0,"totalPages":0}
                """.data(using: .utf8)!
                return (200, json)
            }
            let json = """
            {"items":[],"org":null}
            """.data(using: .utf8)!
            return (200, json)
        }
    }

    @Test func loadWithOrgPrimesLabelStore() async {
        stubEmptyEventsAndMembers(labelsJSON: """
        {"items":[{"id":"l1","org":"org1","naam":"VSB","kleur":"#E08A3C","volgorde":0}],
         "page":1,"perPage":200,"totalItems":1,"totalPages":1}
        """)
        let viewModel = makeViewModel()

        await viewModel.load(userId: "me", orgId: "org1", token: "tok")

        #expect(viewModel.labelStore.label(for: "l1")?.naam == "VSB")
    }

    @Test func loadWithoutOrgLeavesLabelStoreEmpty() async {
        stubEmptyEventsAndMembers(labelsJSON: """
        {"items":[],"page":1,"perPage":200,"totalItems":0,"totalPages":0}
        """)
        let viewModel = makeViewModel()

        await viewModel.load(userId: "me", orgId: nil, token: "tok")

        #expect(viewModel.labelStore.orderedLabels.isEmpty)
    }
}
