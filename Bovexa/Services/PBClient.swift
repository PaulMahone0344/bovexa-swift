import Foundation

/// Vaste server-locatie — PocketBase-backend blijft ongewijzigd voor deze milestone.
enum PBEndpoint {
    static let base = URL(string: "https://api.qawayahbase.com")!
}

/// Dunne PocketBase-client op URLSession — alleen wat deze milestone nodig heeft:
/// authWithPassword, authRefresh, getFullList (filter/sort) en custom POST-routes.
final class PBClient {
    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder

    init(baseURL: URL = PBEndpoint.base, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = JSONDecoder()
    }

    func authWithPassword(email: String, password: String) async throws -> AuthResponse {
        var request = URLRequest(url: baseURL.appendingPathComponent("/api/collections/agenda_users/auth-with-password"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["identity": email, "password": password])
        return try await send(request)
    }

    func authRefresh(token: String) async throws -> AuthResponse {
        var request = URLRequest(url: baseURL.appendingPathComponent("/api/collections/agenda_users/auth-refresh"))
        request.httpMethod = "POST"
        request.setValue(token, forHTTPHeaderField: "Authorization")
        return try await send(request)
    }

    /// Registratie (valkuil A) — publieke create op agenda_users, nog geen token.
    func register(email: String, password: String, naam: String) async throws -> AgendaUser {
        var request = URLRequest(url: baseURL.appendingPathComponent("/api/collections/agenda_users/records"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode([
            "email": email, "password": password, "passwordConfirm": password, "naam": naam,
        ])
        return try await send(request)
    }

    /// Stuurt een herstelmail; PB antwoordt zonder body, dus geen decode nodig.
    func requestPasswordReset(email: String) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("/api/collections/agenda_users/request-password-reset"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["email": email])
        _ = try await perform(request)
    }

    func getFullList<T: Decodable>(_ type: T.Type, collection: String, filter: String, sort: String? = nil, expand: String? = nil, token: String) async throws -> [T] {
        var results: [T] = []
        var page = 1
        let perPage = 200

        while true {
            var components = URLComponents(url: baseURL.appendingPathComponent("/api/collections/\(collection)/records"), resolvingAgainstBaseURL: false)!
            var query = [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "perPage", value: String(perPage)),
            ]
            if !filter.isEmpty { query.append(URLQueryItem(name: "filter", value: filter)) }
            if let sort { query.append(URLQueryItem(name: "sort", value: sort)) }
            if let expand { query.append(URLQueryItem(name: "expand", value: expand)) }
            components.queryItems = query

            var request = URLRequest(url: components.url!)
            request.setValue(token, forHTTPHeaderField: "Authorization")
            let pageResponse: ListResponse<T> = try await send(request)
            results.append(contentsOf: pageResponse.items)

            if pageResponse.items.isEmpty || page >= pageResponse.totalPages { break }
            page += 1
        }

        return results
    }

    func postCustom<T: Decodable>(_ type: T.Type, path: String, token: String) async throws -> T {
        try await postCustom(type, path: path, body: [:], token: token)
    }

    /// POST met een JSON-body naar een custom route (geen collection-record) —
    /// gebruikt door de company/team-routes (valkuil A: alles via routes).
    func postCustom<T: Decodable>(_ type: T.Type, path: String, body: [String: Any], token: String) async throws -> T {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await send(request)
    }

    /// Multipart POST voor bestandsupload (logo) — enige plek in de app die dit nodig heeft.
    func postMultipart<T: Decodable>(_ type: T.Type, path: String, fieldName: String, fileName: String, mimeType: String, fileData: Data, token: String) async throws -> T {
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        return try await send(request)
    }

    /// POST een nieuwe record — body is een los JSON-object (zie AppointmentCreatePayload),
    /// dus JSONSerialization i.p.v. JSONEncoder.
    func createRecord<T: Decodable>(_ type: T.Type, collection: String, body: [String: Any], token: String) async throws -> T {
        var request = URLRequest(url: baseURL.appendingPathComponent("/api/collections/\(collection)/records"))
        request.httpMethod = "POST"
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await send(request)
    }

    /// PATCH op een losse record — body is een los JSON-object (geen uniform Encodable-type,
    /// zie EventUpdatePayload), dus JSONSerialization i.p.v. JSONEncoder.
    func updateRecord<T: Decodable>(_ type: T.Type, collection: String, id: String, body: [String: Any], token: String) async throws -> T {
        var request = URLRequest(url: baseURL.appendingPathComponent("/api/collections/\(collection)/records/\(id)"))
        request.httpMethod = "PATCH"
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await send(request)
    }

    /// Valkuil I: verwijderen is onomkeerbaar — de server ruimt gekoppelde data
    /// op via cascade, hier alleen de aanroep zelf.
    func deleteAccount(id: String, token: String) async throws {
        try await deleteRecord(collection: "agenda_users", id: id, token: token)
    }

    func deleteRecord(collection: String, id: String, token: String) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("/api/collections/\(collection)/records/\(id)"))
        request.httpMethod = "DELETE"
        request.setValue(token, forHTTPHeaderField: "Authorization")
        _ = try await perform(request)
    }

    private func perform(_ request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw PBError.network
        }

        guard let http = response as? HTTPURLResponse else { throw PBError.network }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? decoder.decode(PBErrorBody.self, from: data))?.message ?? "Er ging iets mis."
            throw PBError.server(status: http.statusCode, message: message)
        }
        return data
    }

    private func send<T: Decodable>(_ request: URLRequest) async throws -> T {
        let data = try await perform(request)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw PBError.decoding
        }
    }
}

private struct ListResponse<T: Decodable>: Decodable {
    let items: [T]
    let page: Int
    let perPage: Int
    let totalItems: Int
    let totalPages: Int
}
