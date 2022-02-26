
import Foundation
@_exported import OpenCombineShim

class OptionalStrategy<Wrapped : Codable>: SyncStrategy {
    enum OptionalEventHandlingError: Error {
        case cannotHandleInsertion
        case cannotPropagateInsertionToSubPathOfNil
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
        case .insert(let path, _, _) where path.isEmpty:
            throw OptionalEventHandlingError.cannotHandleInsertion
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
        case .insert(_, _, _):
            switch value {
            case .none:
                throw OptionalEventHandlingError.cannotPropagateInsertionToSubPathOfNil
            case .some(var wrapped):
                let result = try wrappedStrategy.handle(event: event, with: context, for: &wrapped, from: connectionId)
                value = wrapped
                return result
            }
        }
    }

    func events(from previous: Wrapped?, to next: Wrapped?, with context: EventCodingContext, from connectionId: UUID) -> [InternalEvent] {
        switch (previous, next) {
        case (.some, .none):
            return [.delete([])]
        default:
            guard let data = try? context.encode(next) else { return [] }
            return [.write([], data)]
        }
    }

    func subEvents(for value: Wrapped?, with context: EventCodingContext, from connectionId: UUID) -> AnyPublisher<InternalEvent, Never> {
        guard let value = value else {
            return Empty(completeImmediately: false).eraseToAnyPublisher()
        }
        return wrappedStrategy.subEvents(for: value, with: context, from: connectionId)
    }
}

extension Optional: HasErasedSyncStrategy where Wrapped: Codable {}

extension Optional: SyncableType where Wrapped: Codable {
    static var strategy: OptionalStrategy<Wrapped> {
        return OptionalStrategy(extractStrategy(for: Wrapped.self))
    }
}
