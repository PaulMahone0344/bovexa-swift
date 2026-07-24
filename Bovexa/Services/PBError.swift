enum PBError: Error, Equatable {
    case network
    case server(status: Int, message: String)
    case decoding
}

struct PBErrorBody: Decodable {
    let message: String
}
