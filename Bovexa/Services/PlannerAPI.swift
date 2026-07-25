import Foundation

/// Nederlandse foutteksten voor de AI-planner — geport uit requestPlan() in
/// ~/Desktop/agenda-app/src/lib/aiPlanner.ts.
enum PlannerAPIError: Error, Equatable {
    case timeout
    case network
    case server(message: String)
    case invalidResponse

    var message: String {
        switch self {
        case .timeout:
            return "De planner reageert nu traag. Probeer het zo nog een keer."
        case .network:
            return "Geen verbinding met de planner. Check je internet en probeer opnieuw."
        case .server(let message):
            return message
        case .invalidResponse:
            return "Onverwacht antwoord van de planner."
        }
    }
}

private struct PlanRequestBody: Encodable {
    let messages: [ChatTurn]
}

/// Foutvorm van het AI-endpoint zelf: `{ error: string }` — anders dan PocketBase-
/// collectionfouten (`PBErrorBody`, veld "message"). Zie requestPlan() in aiPlanner.ts.
private struct PlannerErrorBody: Decodable {
    let error: String
}

/// Client voor POST /functions/agenda/ai-plan (Node-container, apart van de
/// PocketBase-collections). Authorization = het kale PB-token, GEEN "Bearer "-prefix.
final class PlannerAPI {
    /// De planner doet server-side een Claude-call; die kan traag zijn. Zonder harde
    /// grens blijft de UI oneindig op "Even kijken…" hangen (zie aiPlanner.ts).
    static let timeoutSeconds: TimeInterval = 45

    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let timeout: TimeInterval

    init(baseURL: URL = PBEndpoint.base, session: URLSession = .shared, timeout: TimeInterval = PlannerAPI.timeoutSeconds) {
        self.baseURL = baseURL
        self.session = session
        self.timeout = timeout
        self.decoder = JSONDecoder()
    }

    func requestPlan(messages: [ChatTurn], token: String) async throws -> PlanResponse {
        var request = URLRequest(url: baseURL.appendingPathComponent("/functions/agenda/ai-plan"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.timeoutInterval = timeout
        request.httpBody = try JSONEncoder().encode(PlanRequestBody(messages: messages))

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            if let urlError = error as? URLError, urlError.code == .timedOut {
                throw PlannerAPIError.timeout
            }
            throw PlannerAPIError.network
        }

        guard let http = response as? HTTPURLResponse else { throw PlannerAPIError.network }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? decoder.decode(PlannerErrorBody.self, from: data))?.error ?? "Planning mislukt. Probeer het nog een keer."
            throw PlannerAPIError.server(message: message)
        }

        guard let plan = try? decoder.decode(PlanResponse.self, from: data) else {
            throw PlannerAPIError.invalidResponse
        }
        return plan
    }
}
