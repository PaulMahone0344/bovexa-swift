import Testing
import Foundation
@testable import Bovexa

@MainActor
struct JoinCoordinatorTests {
    init() {
        URLProtocolStub.requestHandler = nil
    }

    private func makeCoordinator() -> JoinCoordinator {
        JoinCoordinator(repository: CompanyRepository(client: PBClient(session: URLProtocolStub.makeSession())))
    }

    // Valkuil G, uitkomst 2: al lid van een bedrijf.
    @Test func alreadyHasCompanySkipsRequestAndSetsAlreadyMember() async {
        URLProtocolStub.requestHandler = { _ in Issue.record("mocht geen request doen"); return (500, Data()) }
        let coordinator = makeCoordinator()
        await coordinator.join(code: "X", alreadyHasCompany: true, token: "tok")
        #expect(coordinator.outcome == .alreadyMember)
    }

    // Valkuil G, uitkomst 3: toetreden lukt.
    @Test func joinSuccessSetsJoined() async {
        URLProtocolStub.requestHandler = { _ in
            (200, """
            {"id":"org1","name":"Bovexa BV","join_code":"BOVEXA-7F3K","plan":"free","seats_max":3,"role":"member"}
            """.data(using: .utf8)!)
        }
        let coordinator = makeCoordinator()
        await coordinator.join(code: "BOVEXA-7F3K", alreadyHasCompany: false, token: "tok")
        #expect(coordinator.outcome == .joined)
    }

    @Test func joinFailureSurfacesServerMessage() async {
        URLProtocolStub.requestHandler = { _ in
            (400, """
            {"message":"Ongeldige bedrijfscode."}
            """.data(using: .utf8)!)
        }
        let coordinator = makeCoordinator()
        await coordinator.join(code: "X", alreadyHasCompany: false, token: "tok")
        #expect(coordinator.outcome == .failed("Ongeldige bedrijfscode."))
    }

    @Test func resetClearsOutcomeAndPendingCode() async {
        let coordinator = makeCoordinator()
        coordinator.pendingCode = "X"
        await coordinator.join(code: "X", alreadyHasCompany: true, token: "tok")
        coordinator.reset()
        #expect(coordinator.outcome == .idle)
        #expect(coordinator.pendingCode == nil)
    }
}
