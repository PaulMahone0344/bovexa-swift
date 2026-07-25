import Foundation

/// Netwerk-stub voor tests: geen enkel verzoek verlaat het toestel.
final class URLProtocolStub: URLProtocol {
    static var requestHandler: ((URLRequest) -> (Int, Data))?
    /// Voor het testen van netwerk-foutpaden (timeout, geen verbinding) zonder een
    /// echte (trage) request — geeft voorrang boven `requestHandler`.
    static var errorHandler: ((URLRequest) -> Error)?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        if let errorHandler = URLProtocolStub.errorHandler {
            client?.urlProtocol(self, didFailWithError: errorHandler(request))
            return
        }
        guard let handler = URLProtocolStub.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let (status, data) = handler(request)
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: status,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]
        return URLSession(configuration: config)
    }
}
