protocol TokenStore {
    func load() -> String?
    func save(_ token: String)
    func clear()
}
