import Testing
import Foundation
@testable import Bovexa

/// PlannerAPI.requestPlan — verzoekvorm (kaal token, geen "Bearer"), 45s-timeout-
/// mapping en Nederlandse foutteksten. Geport uit requestPlan() in
/// ~/Desktop/agenda-app/src/lib/aiPlanner.ts.
struct PlannerAPITests {
    init() {
        URLProtocolStub.requestHandler = nil
        URLProtocolStub.errorHandler = nil
    }

    private func makeAPI() -> PlannerAPI {
        PlannerAPI(session: URLProtocolStub.makeSession())
    }

    private func bodyData(from request: URLRequest) -> Data {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: buffer.count)
            guard read > 0 else { break }
            data.append(buffer, count: read)
        }
        return data
    }

    @Test func sendsRawTokenWithoutBearerPrefixAndPostsFullHistory() async throws {
        URLProtocolStub.requestHandler = { request in
            #expect(request.httpMethod == "POST")
            #expect(request.url!.absoluteString.contains("/functions/agenda/ai-plan"))
            #expect(request.value(forHTTPHeaderField: "Authorization") == "raw-token-123")
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
            let body = try! JSONSerialization.jsonObject(with: self.bodyData(from: request)) as! [String: Any]
            let messages = body["messages"] as! [[String: String]]
            #expect(messages == [["role": "user", "content": "Morgen 15:00 tandarts"]])
            let json = """
            {"status":"needs_clarification","message":"Welke dag?","question":"Welke dag?","options":[],"appointments":[]}
            """.data(using: .utf8)!
            return (200, json)
        }
        let api = makeAPI()
        let plan = try await api.requestPlan(messages: [ChatTurn(role: .user, content: "Morgen 15:00 tandarts")], token: "raw-token-123")
        #expect(plan.status == .needsClarification)
    }

    @Test func mapsReadyResponseWithAppointments() async throws {
        URLProtocolStub.requestHandler = { _ in
            let json = """
            {"status":"ready","message":"Klaar!","question":null,"options":[],
             "appointments":[{"title":"Tandarts","date":"2026-08-03","start":"09:00","end":"09:30","category":"body"}]}
            """.data(using: .utf8)!
            return (200, json)
        }
        let api = makeAPI()
        let plan = try await api.requestPlan(messages: [], token: "tok")
        #expect(plan.status == .ready)
        #expect(plan.appointments.count == 1)
    }

    @Test func nonOkStatusThrowsServerErrorWithBodyMessage() async {
        URLProtocolStub.requestHandler = { _ in
            let json = """
            {"error":"Geen bedrijf gekoppeld."}
            """.data(using: .utf8)!
            return (400, json)
        }
        let api = makeAPI()
        do {
            _ = try await api.requestPlan(messages: [], token: "tok")
            Issue.record("had moeten falen")
        } catch let error as PlannerAPIError {
            #expect(error == .server(message: "Geen bedrijf gekoppeld."))
        } catch {
            Issue.record("verkeerd fouttype: \(error)")
        }
    }

    @Test func nonOkStatusWithoutBodyMessageFallsBackToDefaultText() async {
        URLProtocolStub.requestHandler = { _ in (500, Data()) }
        let api = makeAPI()
        do {
            _ = try await api.requestPlan(messages: [], token: "tok")
            Issue.record("had moeten falen")
        } catch let error as PlannerAPIError {
            #expect(error == .server(message: "Planning mislukt. Probeer het nog een keer."))
        } catch {
            Issue.record("verkeerd fouttype: \(error)")
        }
    }

    @Test func invalidJsonShapeThrowsInvalidResponse() async {
        URLProtocolStub.requestHandler = { _ in (200, Data("{\"onzin\":true}".utf8)) }
        let api = makeAPI()
        do {
            _ = try await api.requestPlan(messages: [], token: "tok")
            Issue.record("had moeten falen")
        } catch let error as PlannerAPIError {
            #expect(error == .invalidResponse)
        } catch {
            Issue.record("verkeerd fouttype: \(error)")
        }
    }

    @Test func timeoutErrorMapsToTraageMelding() async {
        URLProtocolStub.errorHandler = { _ in URLError(.timedOut) }
        let api = makeAPI()
        do {
            _ = try await api.requestPlan(messages: [], token: "tok")
            Issue.record("had moeten falen")
        } catch let error as PlannerAPIError {
            #expect(error == .timeout)
            #expect(error.message == "De planner reageert nu traag. Probeer het zo nog een keer.")
        } catch {
            Issue.record("verkeerd fouttype: \(error)")
        }
    }

    @Test func otherNetworkErrorMapsToGeenVerbindingMelding() async {
        URLProtocolStub.errorHandler = { _ in URLError(.notConnectedToInternet) }
        let api = makeAPI()
        do {
            _ = try await api.requestPlan(messages: [], token: "tok")
            Issue.record("had moeten falen")
        } catch let error as PlannerAPIError {
            #expect(error == .network)
            #expect(error.message == "Geen verbinding met de planner. Controleer je internet en probeer opnieuw.")
        } catch {
            Issue.record("verkeerd fouttype: \(error)")
        }
    }

    @Test func requestTimeoutIntervalIs45Seconds() async throws {
        URLProtocolStub.requestHandler = { request in
            #expect(request.timeoutInterval == 45)
            let json = """
            {"status":"needs_clarification","message":"?","question":null,"options":[],"appointments":[]}
            """.data(using: .utf8)!
            return (200, json)
        }
        _ = try await makeAPI().requestPlan(messages: [], token: "tok")
    }
}
