@testable import Bovexa

final class InMemoryTokenStore: TokenStore {
    private var stored: String?

    func load() -> String? { stored }
    func save(_ token: String) { stored = token }
    func clear() { stored = nil }
}
