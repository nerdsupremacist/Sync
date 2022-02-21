
import Foundation
import OpenCombineShim

class AnySyncStrategy<Value>: SyncStrategy {
    private class BaseStorage {
        func handle(event: InternalEvent, with context: EventCodingContext, for value: inout Value, from connectionId: UUID) throws -> EventSyncHandlingResult{
            fatalError()
        }

        func events(from previous: Value, to next: Value,  with context: EventCodingContext, from connectionId: UUID) -> [InternalEvent] {
            fatalError()
        }

        func subEvents(for value: Value, with context: EventCodingContext, from connectionId: UUID) -> AnyPublisher<InternalEvent, Never> {
            fatalError()
        }
    }

    private class Storage<Strategy: SyncStrategy>: BaseStorage where Strategy.Value == Value {
        private let strategy: Strategy

        init(_ strategy: Strategy) {
            self.strategy = strategy
        }

        override func handle(event: InternalEvent, with context: EventCodingContext, for value: inout Value, from connectionId: UUID) throws -> EventSyncHandlingResult{
            return try strategy.handle(event: event, with: context, for: &value, from: connectionId)
        }

        override func events(from previous: Value, to next: Value,  with context: EventCodingContext, from connectionId: UUID) -> [InternalEvent] {
            return strategy.events(from: previous, to: next, with: context, from: connectionId)
        }

        override func subEvents(for value: Value, with context: EventCodingContext, from connectionId: UUID) -> AnyPublisher<InternalEvent, Never> {
            return strategy.subEvents(for: value, with: context, from: connectionId)
        }
    }

    private let storage: BaseStorage

    init<Strategy: SyncStrategy>(_ strategy: Strategy) where Strategy.Value == Value {
        self.storage = Storage(strategy)
    }

    func handle(event: InternalEvent, with context: EventCodingContext, for value: inout Value, from connectionId: UUID) throws -> EventSyncHandlingResult {
        return try storage.handle(event: event, with: context, for: &value, from: connectionId)
    }

    func events(from previous: Value, to next: Value,  with context: EventCodingContext, from connectionId: UUID) -> [InternalEvent] {
        return storage.events(from: previous, to: next, with: context, from: connectionId)
    }
    
    func subEvents(for value: Value, with context: EventCodingContext, from connectionId: UUID) -> AnyPublisher<InternalEvent, Never> {
        return storage.subEvents(for: value, with: context, from: connectionId)
    }
}
