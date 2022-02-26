
import Foundation
@_exported import OpenCombineShim

enum EventSyncHandlingResult {
    case done
    case alertRemainingConnections
}

protocol SyncStrategy {
    associatedtype Value

    func handle(event: InternalEvent, with context: EventCodingContext, for value: inout Value, from connectionId: UUID) throws -> EventSyncHandlingResult

    func events(from previous: Value, to next: Value,  with context: EventCodingContext, from connectionId: UUID) -> [InternalEvent]
    func subEvents(for value: Value, with context: EventCodingContext, from connectionId: UUID) -> AnyPublisher<InternalEvent, Never>
}

protocol SelfContainedStrategy {
    func handle(event: InternalEvent, with context: EventCodingContext, from connectionId: UUID) throws
    func events(with context: EventCodingContext, from connectionId: UUID) -> AnyPublisher<InternalEvent, Never>
}
