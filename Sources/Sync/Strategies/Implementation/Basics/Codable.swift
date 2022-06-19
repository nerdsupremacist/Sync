
import Foundation
@_exported import OpenCombineShim

class CodableStrategy<Value : Codable>: SyncStrategy {
    enum CodableEventHandlingError: Error {
        case codableCannotBeDeleted
        case codableDoesNotAcceptSubPaths
    }

    init() { }

    func handle(event: InternalEvent, from context: ConnectionContext, for value: inout Value) throws -> EventSyncHandlingResult {
        guard case .write(let path, let data) = event else {
            throw CodableEventHandlingError.codableCannotBeDeleted
        }
        guard path.isEmpty else {
            throw CodableEventHandlingError.codableDoesNotAcceptSubPaths
        }
        value = try context.codingContext.decode(data: data, as: Value.self)
        return .alertRemainingConnections
    }

    func events(from previous: Value, to next: Value, for context: ConnectionContext) -> [InternalEvent] {
        guard let data = try? context.codingContext.encode(next) else { return [] }
        return [.write([], data)]
    }

    func subEvents(for value: Value, for context: ConnectionContext) -> AnyPublisher<InternalEvent, Never> {
        return Empty(completeImmediately: false).eraseToAnyPublisher()
    }
}
