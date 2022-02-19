
import Foundation
import Combine

class AnySyncStrategy<Value>: SyncStrategy {
    private class BaseStorage {
        func handle(event: InternalEvent, with context: EventCodingContext, for value: inout Value) throws {
            fatalError()
        }

        func events(for value: AnyPublisher<Value, Never>, with context: EventCodingContext) -> AnyPublisher<InternalEvent, Never> {
            fatalError()
        }
    }

    private class Storage<Strategy: SyncStrategy>: BaseStorage where Strategy.Value == Value {
        private let strategy: Strategy

        init(_ strategy: Strategy) {
            self.strategy = strategy
        }

        override func handle(event: InternalEvent, with context: EventCodingContext, for value: inout Value) throws {
            try strategy.handle(event: event, with: context, for: &value)
        }

        override func events(for value: AnyPublisher<Value, Never>, with context: EventCodingContext) -> AnyPublisher<InternalEvent, Never> {
            return strategy.events(for: value, with: context)
        }
    }

    private let storage: BaseStorage

    init<Strategy: SyncStrategy>(_ strategy: Strategy) where Strategy.Value == Value {
        self.storage = Storage(strategy)
    }

    func handle(event: InternalEvent, with context: EventCodingContext, for value: inout Value) throws {
        try storage.handle(event: event, with: context, for: &value)
    }

    func events(for value: AnyPublisher<Value, Never>, with context: EventCodingContext) -> AnyPublisher<InternalEvent, Never> {
        return storage.events(for: value, with: context)
    }
}
