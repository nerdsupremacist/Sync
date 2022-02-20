
import Foundation
import Combine

class OptionalStrategy<Wrapped : Codable>: SyncStrategy {
    enum OptionalEventHandlingError: Error {
        case cannotPropagateDeletionToSubPathOfNil
        case cannotPropagateWriteToSubPathOfNil
    }
    typealias Value = Wrapped?

    let wrappedStrategy: AnySyncStrategy<Wrapped>

    init(_ wrappedStrategy: AnySyncStrategy<Wrapped>) {
        self.wrappedStrategy = wrappedStrategy
    }

    func handle(event: InternalEvent, with context: EventCodingContext, for value: inout Wrapped?, from connectionId: UUID) throws -> EventSyncHandlingResult {
        switch event {
        case .delete(let path) where path.isEmpty:
            value = nil
            return .alertRemainingConnections
        case .delete:
            guard case .some(var wrapped) = value else {
                throw OptionalEventHandlingError.cannotPropagateDeletionToSubPathOfNil
            }
            let result = try wrappedStrategy.handle(event: event, with: context, for: &wrapped, from: connectionId)
            value = wrapped
            return result
        case .write(let path, let data):
            switch value {
            case .none where path.isEmpty:
                value = try context.decode(data: data, as: Wrapped.self)
                return .alertRemainingConnections
            case .none:
                throw OptionalEventHandlingError.cannotPropagateWriteToSubPathOfNil
            case .some(var wrapped):
                let result = try wrappedStrategy.handle(event: event, with: context, for: &wrapped, from: connectionId)
                value = wrapped
                return result
            }
        }
    }

    func events(for value: AnyPublisher<Wrapped?, Never>, with context: EventCodingContext, from connectionId: UUID) -> AnyPublisher<InternalEvent, Never> {
        return value.flatMap { value -> AnyPublisher<InternalEvent, Never> in
            switch value {
            case .none:
                return Just(.delete([])).eraseToAnyPublisher()
            case .some(let value):
                return self.wrappedStrategy.events(for: Just(value).eraseToAnyPublisher(), with: context, from: connectionId)
            }
        }
        .eraseToAnyPublisher()
    }
}

extension Optional: HasErasedSyncStrategy where Wrapped: Codable {}

extension Optional: SyncableType where Wrapped: Codable {
    static var strategy: OptionalStrategy<Wrapped> {
        return OptionalStrategy(extractStrategy(for: Wrapped.self))
    }
}
