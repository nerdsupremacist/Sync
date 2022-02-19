
import Foundation
import Combine

protocol SyncStrategy {
    associatedtype Value

    func handle(event: InternalEvent, with context: EventCodingContext, for value: inout Value) throws
    func events(for value: AnyPublisher<Value, Never>, with context: EventCodingContext) -> AnyPublisher<InternalEvent, Never>
}

protocol SelfContainedStrategy {
    func handle(event: InternalEvent, with context: EventCodingContext) throws
    func events(with context: EventCodingContext) -> AnyPublisher<InternalEvent, Never>
}
