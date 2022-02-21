
import Foundation
import OpenCombineShim

@propertyWrapper
public final class Synced<Value : Codable>: Codable {
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

        func shouldBeSent(to connectionId: UUID) -> Bool {
            switch self {
            case .local:
                return true
            case .remote(_, let id):
                return connectionId != id
            }
        }
    }

    private let publisher: CurrentValueSubject<ValueChange, Never>
    private var value: Value
    private let strategy: AnySyncStrategy<Value>

    public var wrappedValue: Value {
        get {
            return value
        }
        set {
            value = newValue
            publisher.send(.local(newValue))
        }
    }

    public var valueChange: AnyPublisher<Value, Never> {
        return publisher.map(\.value).eraseToAnyPublisher()
    }

    init(value: Value) {
        self.value = value
        self.publisher = CurrentValueSubject(.local(value))
        self.strategy = extractStrategy(for: Value.self)
    }

    public convenience init(wrappedValue value: Value) {
        self.init(value: value)
    }

    public convenience init(from decoder: Decoder) throws {
        self.init(value: try Value(from: decoder))
    }

    public func encode(to encoder: Encoder) throws {
        return try value.encode(to: encoder)
    }
}

extension Synced: SelfContainedStrategy {
    func handle(event: InternalEvent, with context: EventCodingContext, from connectionId: UUID) throws {
        switch try strategy.handle(event: event, with: context, for: &value, from: connectionId) {
        case .alertRemainingConnections:
            publisher.send(.remote(value, connectionId: connectionId))
        case .done:
            break
        }
    }

    func events(with context: EventCodingContext, from connectionId: UUID) -> AnyPublisher<InternalEvent, Never> {
        let strategy = strategy
        return publisher
            .withPrevious()
            .filter { $0.current.shouldBeSent(to: connectionId) }
            .map { (previous: $0.previous?.value, current: $0.current.value) }
            .flatMap { [strategy] previous, current -> AnyPublisher<InternalEvent, Never> in
                let events = previous.map { strategy.events(from: $0, to: current, with: context, from: connectionId) } ?? []
                let immediate = Publishers.Sequence<[InternalEvent], Never>(sequence: events)
                let future = strategy.subEvents(for: current, with: context, from: connectionId)
                return immediate.merge(with: future).eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
}

extension Publisher {

    typealias OutputWithPrevious = (previous: Output?, current: Output)

    fileprivate func withPrevious() -> AnyPublisher<OutputWithPrevious, Failure> {
        scan(Optional<OutputWithPrevious>.none) { ($0?.current, $1) }
        .compactMap { $0 }
        .eraseToAnyPublisher()
    }

}
