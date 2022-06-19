
import Foundation
@_exported import OpenCombineShim

enum EventSyncHandlingResult {
    case done
    case alertRemainingConnections
}

protocol ConnectionContext {
    var id: UUID { get }
    var type: ConnectionType { get }
    var connection: Connection { get }
}

extension ConnectionContext {

    var codingContext: EventCodingContext {
        return connection.codingContext
    }

}

protocol SyncStrategy {
    associatedtype Value

    func handle(event: InternalEvent, from context: ConnectionContext, for value: inout Value) throws -> EventSyncHandlingResult

    func events(from previous: Value, to next: Value,  for context: ConnectionContext) -> [InternalEvent]
    func subEvents(for value: Value, for context: ConnectionContext) -> AnyPublisher<InternalEvent, Never>
}

protocol SelfContainedStrategy {
    func handle(event: InternalEvent, from context: ConnectionContext) throws
    func events(for context: ConnectionContext) -> AnyPublisher<InternalEvent, Never>
}
