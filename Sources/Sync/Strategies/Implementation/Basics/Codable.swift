
import Foundation
import Combine

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

    func events(for value: AnyPublisher<Value, Never>, with context: EventCodingContext, from connectionId: UUID) -> AnyPublisher<InternalEvent, Never> {
        return value
            .dropFirst()
            .compactMap { value in
                guard let data = try? context.encode(value) else { return nil }
                return .write([], data)
            }
            .eraseToAnyPublisher()
    }
}
