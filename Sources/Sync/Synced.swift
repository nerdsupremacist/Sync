
import Foundation
import Combine

@propertyWrapper
public final class Synced<Value : Codable>: Codable {
    private let subject: CurrentValueSubject<Value, Never>
    private var value: Value
    private let strategy: AnySyncStrategy<Value>

    public var wrappedValue: Value {
        get {
            return value
        }
        set {
            value = newValue
            subject.send(newValue)
        }
    }

    init(value: Value) {
        self.value = value
        self.subject = CurrentValueSubject(value)
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
    func handle(event: InternalEvent, with context: EventCodingContext) throws {
        try strategy.handle(event: event, with: context, for: &value)
    }

    func events(with context: EventCodingContext) -> AnyPublisher<InternalEvent, Never> {
        return strategy.events(for: subject.eraseToAnyPublisher(), with: context)
    }
}
