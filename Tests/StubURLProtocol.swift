import Foundation

/// Answers every request from `handler` so tests never reach the NHL API.
final class StubURLProtocol: URLProtocol {
    static let unstubbed: (URLRequest) throws -> (Int, Data) = {
        throw URLError(.notConnectedToInternet, userInfo: [NSLocalizedDescriptionKey: "Unstubbed request: \($0.url!)"])
    }
    static var handler = unstubbed

    static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: config)
    }()

    /// Stubs a status and body for every request, and records the requested URLs.
    static func respond(_ status: Int, _ body: Data = Data()) -> () -> [URL] {
        var urls: [URL] = []
        handler = { request in
            urls.append(request.url!)
            return (status, body)
        }
        return { urls }
    }

    /// Call from `setUp`: blocks real network for the whole process, including `URLSession.shared`.
    static func install() {
        URLProtocol.registerClass(StubURLProtocol.self)
        handler = unstubbed
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            let (status, data) = try Self.handler(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
