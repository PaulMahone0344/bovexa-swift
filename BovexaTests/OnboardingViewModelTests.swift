import Testing
import Foundation
@testable import Bovexa

@MainActor
struct OnboardingViewModelTests {
    init() {
        URLProtocolStub.requestHandler = nil
    }

    private func makeViewModel() -> OnboardingViewModel {
        OnboardingViewModel(repository: CompanyRepository(client: PBClient(session: URLProtocolStub.makeSession())))
    }

    private func bodyJSON(from request: URLRequest) -> [String: Any] {
        let data: Data
        if let body = request.httpBody {
            data = body
        } else if let stream = request.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var collected = Data()
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let read = stream.read(&buffer, maxLength: buffer.count)
                guard read > 0 else { break }
                collected.append(buffer, count: read)
            }
            data = collected
        } else {
            data = Data()
        }
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    // MARK: - Starttoestand

    @Test func startsAtChoiceWithoutPrefill() {
        let vm = makeViewModel()
        #expect(vm.mode == .choice)
        #expect(vm.joinCode.isEmpty)
    }

    // Valkuil B: code uit een uitnodigingslink staat al klaar.
    @Test func applyPrefilledCodeSwitchesToCodeModeAndFillsField() {
        let vm = makeViewModel()
        vm.applyPrefilledCode("BOVEXA-7F3K")
        #expect(vm.mode == .code)
        #expect(vm.joinCode == "BOVEXA-7F3K")
    }

    @Test func applyPrefilledCodeIgnoresBlankCode() {
        let vm = makeViewModel()
        vm.applyPrefilledCode("   ")
        #expect(vm.mode == .choice)
        #expect(vm.joinCode.isEmpty)
    }

    // MARK: - Bedrijf starten

    @Test func startCompanyRejectsTooShortName() async {
        let vm = makeViewModel()
        vm.companyName = "B"
        let success = await vm.startCompany(token: "tok")
        #expect(!success)
        #expect(vm.errorMessage == "Vul een bedrijfsnaam in (min. 2 tekens).")
    }

    @Test func startCompanyCallsCreateCompanyRoute() async {
        URLProtocolStub.requestHandler = { request in
            #expect(request.url?.path == "/api/agenda/company/create")
            let json = """
            {"id":"org1","name":"Bovexa BV","join_code":"BOVEXA-7F3K","plan":"free","seats_max":3,"role":"admin"}
            """.data(using: .utf8)!
            return (200, json)
        }
        let vm = makeViewModel()
        vm.companyName = "Bovexa BV"
        let success = await vm.startCompany(token: "tok")
        #expect(success)
        #expect(vm.errorMessage == nil)
    }

    // MARK: - Code invoeren

    @Test func joinCompanyActionRejectsEmptyCode() async {
        let vm = makeViewModel()
        vm.joinCode = " "
        let success = await vm.joinCompanyAction(token: "tok")
        #expect(!success)
        #expect(vm.errorMessage == "Vul een bedrijfscode in.")
    }

    @Test func joinCompanyActionCallsJoinCompanyRouteWithCode() async {
        URLProtocolStub.requestHandler = { request in
            #expect(request.url?.path == "/api/agenda/company/join")
            #expect(self.bodyJSON(from: request)["code"] as? String == "BOVEXA-7F3K")
            let json = """
            {"id":"org1","name":"Bovexa BV","join_code":"BOVEXA-7F3K","plan":"free","seats_max":3,"role":"member"}
            """.data(using: .utf8)!
            return (200, json)
        }
        let vm = makeViewModel()
        vm.joinCode = "BOVEXA-7F3K"
        let success = await vm.joinCompanyAction(token: "tok")
        #expect(success)
    }

    @Test func joinCompanyActionSurfacesServerError() async {
        URLProtocolStub.requestHandler = { _ in
            (400, """
            {"message":"Ongeldige bedrijfscode."}
            """.data(using: .utf8)!)
        }
        let vm = makeViewModel()
        vm.joinCode = "X"
        let success = await vm.joinCompanyAction(token: "tok")
        #expect(!success)
        #expect(vm.errorMessage == "Ongeldige bedrijfscode.")
    }
}
