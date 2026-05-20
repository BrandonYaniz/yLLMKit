import Foundation

public protocol AnthropicTransport: Sendable {
    func stream(for request: URLRequest) -> AsyncThrowingStream<Data, Error>
}

public struct URLSessionAnthropicTransport: AnthropicTransport {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func stream(for request: URLRequest) -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let (bytes, response) = try await session.bytes(for: request)
                    if let httpResponse = response as? HTTPURLResponse,
                       !(200..<300).contains(httpResponse.statusCode) {
                        throw AnthropicHTTPError(statusCode: httpResponse.statusCode)
                    }

                    for try await byte in bytes {
                        continuation.yield(Data([byte]))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
}

public struct AnthropicHTTPError: Error, Sendable, Hashable {
    public var statusCode: Int

    public init(statusCode: Int) {
        self.statusCode = statusCode
    }
}
