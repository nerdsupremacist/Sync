
import Foundation
import OpenCombineShim

public final class EventBus<Event : Codable>: Codable {
    enum EventBusEventHandlingError: Error {
        case writeAtSubpathNotAllowed
        case deleteNotAllowed
        case insertNotAllowed
    }

    private let outgoingEventSubject = PassthroughSubject<Event, Never>()
    private let incomingEventSubject = PassthroughSubject<Event, Never>()

    public var events: AnyPublisher<Event, Never> {
        return incomingEventSubject.eraseToAnyPublisher()
    }

    public init() { }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        assert(container.decodeNil())
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encodeNil()
    }

    public func send(_ event: Event) {
        outgoingEventSubject.send(event)
    }
}

extension EventBus: SelfContainedStrategy {
    func handle(event: InternalEvent, from context: ConnectionContext) throws {
        switch event {
        case .write(let path, let data) where path.isEmpty:
            let event = try context.codingContext.decode(data: data, as: Event.self)
            incomingEventSubject.send(event)
        case .write:
            throw EventBusEventHandlingError.writeAtSubpathNotAllowed
        case .delete:
            throw EventBusEventHandlingError.deleteNotAllowed
        case .insert:
            throw EventBusEventHandlingError.insertNotAllowed
        }
    }

    func events(for context: ConnectionContext) -> AnyPublisher<InternalEvent, Never> {
        return outgoingEventSubject
            .compactMap { event in
                guard let data = try? context.codingContext.encode(event) else { return nil }
                return .write([], data)
            }
            .eraseToAnyPublisher()
    }
}
