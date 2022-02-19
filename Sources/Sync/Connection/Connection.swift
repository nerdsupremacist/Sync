
import Foundation
import Combine

public protocol Connection {
    var isConnected: Bool { get }
    var codingContext: EventCodingContext { get }

    func disconnect()

    func send(data: Data)
    func receive() -> AnyPublisher<Data, Never>
}

public protocol ConsumerConnection: Connection {
    func connect() async throws -> Data
}

public protocol ProducerConnection: Connection { }
