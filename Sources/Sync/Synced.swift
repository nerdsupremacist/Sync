
import Foundation
import OpenCombineShim

@propertyWrapper
public final class Synced<Value : Codable>: Codable {
    private let publishers = PublisherPerConnectionMap<Value>()
    private var value: Value
    private let strategy: AnySyncStrategy<Value>

    public var wrappedValue: Value {
        get {
            return value
        }
        set {
            value = newValue
            publishers.alertAllConnections(value: newValue)
        }
    }

    init(value: Value) {
        self.value = value
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
            publishers.alertAllConnections(except: connectionId, value: value)
        case .done:
            break
        }
    }

    func events(with context: EventCodingContext, from connectionId: UUID) -> AnyPublisher<InternalEvent, Never> {
        let strategy = strategy
        return publishers
            .publisher(for: connectionId, with: value)
            .withPrevious()
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

    fileprivate func withPrevious() -> AnyPublisher<(previous: Output?, current: Output), Failure> {
        scan(Optional<(Output?, Output)>.none) { ($0?.1, $1) }
        .compactMap { $0 }
        .eraseToAnyPublisher()
    }

}

private class PublisherPerConnectionMap<Value> {
    private var publishers: [UUID : Weak<CurrentValueSubject<Value, Never>>] = [:]

    init() {}

    func purgeRemoved() {
        publishers = publishers.filter { $0.value.value != nil }
    }

    func publisher(for connectionId: UUID, with value: Value) -> CurrentValueSubject<Value, Never> {
        purgeRemoved()
        if let publisher = publishers[connectionId]?.value {
            return publisher
        }

        let publisher = CurrentValueSubject<Value, Never>(value)
        publishers[connectionId] = Weak(value: publisher)
        return publisher
    }

    func alertAllConnections(value: Value) {
        purgeRemoved()
        publishers.values.compactMap(\.value).forEach { publisher in
            publisher.send(value)
        }
    }

    func alertAllConnections(except connectionIdException: UUID, value: Value) {
        purgeRemoved()
        publishers
            .filter({ $0.key != connectionIdException })
            .values
            .compactMap(\.value)
            .forEach { publisher in
                publisher.send(value)
            }
    }
}

private struct Weak<T : AnyObject> {
    private(set) weak var value: T?

    init(value: T) {
        self.value = value
    }
}
