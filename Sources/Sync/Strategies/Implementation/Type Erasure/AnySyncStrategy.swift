
import Foundation
@_exported import OpenCombineShim

class AnySyncStrategy<Value>: SyncStrategy {
    private class BaseStorage {
        func handle(event: InternalEvent, from context: ConnectionContext, for value: inout Value) throws -> EventSyncHandlingResult {
            fatalError()
        }

        func events(from previous: Value, to next: Value, for context: ConnectionContext) -> [InternalEvent] {
            fatalError()
        }

        func subEvents(for value: Value, for context: ConnectionContext) -> AnyPublisher<InternalEvent, Never> {
            fatalError()
        }
    }

    private class Storage<Strategy: SyncStrategy>: BaseStorage where Strategy.Value == Value {
        private let strategy: Strategy

        init(_ strategy: Strategy) {
            self.strategy = strategy
        }

        override func handle(event: InternalEvent, from context: ConnectionContext, for value: inout Value) throws -> EventSyncHandlingResult {
            return try strategy.handle(event: event, from: context, for: &value)
        }

        override func events(from previous: Value, to next: Value, for context: ConnectionContext) -> [InternalEvent] {
            return strategy.events(from: previous, to: next, for: context)
        }

        override func subEvents(for value: Value, for context: ConnectionContext) -> AnyPublisher<InternalEvent, Never> {
            return strategy.subEvents(for: value, for: context)
        }
    }

    private let storage: BaseStorage

    init<Strategy: SyncStrategy>(_ strategy: Strategy) where Strategy.Value == Value {
        self.storage = Storage(strategy)
    }

    func handle(event: InternalEvent, from context: ConnectionContext, for value: inout Value) throws -> EventSyncHandlingResult {
        return try storage.handle(event: event, from: context, for: &value)
    }

    func events(from previous: Value, to next: Value, for context: ConnectionContext) -> [InternalEvent] {
        return storage.events(from: previous, to: next, for: context)
    }
    
    func subEvents(for value: Value, for context: ConnectionContext) -> AnyPublisher<InternalEvent, Never> {
        return storage.subEvents(for: value, for: context)
    }
}
