
import Foundation
import OpenCombineShim

class CodableStrategy<Value : Codable>: SyncStrategy {
    enum CodableEventHandlingError: Error {
        case codableCannotBeDeleted
        case codableDoesNotAcceptSubPaths
    }

    init() { }

    func handle(event: InternalEvent, with context: EventCodingContext, for value: inout Value, from connectionId: UUID) throws -> EventSyncHandlingResult {
        guard case .write(let path, let data) = event else {
            throw CodableEventHandlingError.codableCannotBeDeleted
        }
        guard path.isEmpty else {
            throw CodableEventHandlingError.codableDoesNotAcceptSubPaths
        }
        value = try context.decode(data: data, as: Value.self)
        return .alertRemainingConnections
    }

    func events(from previous: Value, to next: Value, with context: EventCodingContext, from connectionId: UUID) -> [InternalEvent] {
        guard let data = try? context.encode(next) else { return [] }
        return [.write([], data)]
    }

    func subEvents(for value: Value, with context: EventCodingContext, from connectionId: UUID) -> AnyPublisher<InternalEvent, Never> {
        return Empty(completeImmediately: false).eraseToAnyPublisher()
    }
}
