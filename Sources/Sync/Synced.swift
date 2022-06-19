
import Foundation
@_exported import OpenCombineShim
import Accessibility

public enum SyncedWriteRights: Codable {
    case shared
    case protected
}

@propertyWrapper
public final class Synced<Value : Codable>: Codable {
    enum SyncedEventHandlingError: Error {
        case receivedIllegalEventForProtectedProperty
    }

    private struct ConnectionState {
        let value: Value?
        let events: AnyPublisher<InternalEvent, Never>
    }

    private enum ValueChange {
        case local(Value)
        case remote(Value, connectionId: UUID)

        var value: Value {
            switch self {
            case .local(let value):
                return value
            case .remote(let value, _):
                return value
            }
        }

        func handle(previous: ConnectionState, using strategy: AnySyncStrategy<Value>, for context: ConnectionContext) -> ConnectionState {
            switch self {
            case .local(let value):
                return ConnectionState(value: value, events: events(from: previous.value, to: value, using: strategy, for: context))
            case .remote(let value, let connectionId):
                guard connectionId != context.id else {
                    return ConnectionState(value: value, events: events(from: nil, to: value, using: strategy, for: context))
                }
                return ConnectionState(value: value, events: events(from: previous.value, to: value, using: strategy, for: context))
            }
        }

        private func events(from previous: Value?,
                            to current: Value,
                            using strategy: AnySyncStrategy<Value>,
                            for context: ConnectionContext) -> AnyPublisher<InternalEvent, Never> {

            let future = strategy.subEvents(for: current, for: context)
            guard let previous = previous else { return future }

            let events = strategy.events(from: previous, to: current, for: context)
            let immediate = Publishers.Sequence<[InternalEvent], Never>(sequence: events)
            return immediate.merge(with: future).eraseToAnyPublisher()
        }
    }

    private let publisher: CurrentValueSubject<ValueChange, Never>
    private var value: Value
    private let rights: SyncedWriteRights
    private let strategy: AnySyncStrategy<Value>
    private let isAllowedToWrite: Bool

    public var wrappedValue: Value {
        get {
            return value
        }
        set {
            guard isAllowedToWrite else { return }
            value = newValue
            publisher.send(.local(newValue))
        }
    }

    public var values: AnyPublisher<Value, Never> {
        return publisher.map(\.value).eraseToAnyPublisher()
    }

    public var valueChange: AnyPublisher<Value, Never> {
        return publisher.map(\.value).dropFirst().eraseToAnyPublisher()
    }

    public var projectedValue: Synced<Value> {
        return self
    }

    init(value: Value, rights: SyncedWriteRights, isAllowedToWrite: Bool) {
        self.value = value
        self.publisher = CurrentValueSubject(.local(value))
        self.strategy = extractStrategy(for: Value.self)
        self.rights = rights
        self.isAllowedToWrite = isAllowedToWrite
    }

    public convenience init(wrappedValue value: Value, _ rights: SyncedWriteRights = .shared) {
        self.init(value: value, rights: rights, isAllowedToWrite: true)
    }

    public convenience init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let value = try container.decode(Value.self)
        let rights = try container.decode(SyncedWriteRights.self)
        self.init(value: value, rights: rights, isAllowedToWrite: rights != .protected)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(value)
        try container.encode(rights)
    }
}

extension Synced: SelfContainedStrategy {
    func handle(event: InternalEvent, from context: ConnectionContext) throws {
        if case .producer = context.type, case .protected = rights {
            throw SyncedEventHandlingError.receivedIllegalEventForProtectedProperty
        }
        switch try strategy.handle(event: event, from: context, for: &value) {
        case .alertRemainingConnections:
            guard case .producer = context.type else { break }
            publisher.send(.remote(value, connectionId: context.id))
        case .done:
            break
        }
    }

    func events(for context: ConnectionContext) -> AnyPublisher<InternalEvent, Never> {
        let strategy = strategy
        let initialState = ConnectionState(value: nil, events: Empty(completeImmediately: false).eraseToAnyPublisher())
        return publisher
            .scan(initialState) { [strategy, context] state, change in
                return change.handle(previous: state, using: strategy, for: context)
            }
            .flatMap { $0.events }
            .eraseToAnyPublisher()
    }
}
