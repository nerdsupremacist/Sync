
import Foundation
import Combine

class ArrayStrategy<Element : Codable>: SyncStrategy {
    enum ArrayEventHandlingError: Error {
        case expectedIntIndexInPathButReceivedSomethingElse
        case intIndexReceivedOutOfBounds(Int)
        case deletionOfWholeArrayNotAllowed
    }

    typealias Value = [Element]

    let elementStrategy: AnySyncStrategy<Element>

    init(_ elementStrategy: AnySyncStrategy<Element>) {
        self.elementStrategy = elementStrategy
    }

    func handle(event: InternalEvent, with context: EventCodingContext, for value: inout [Element], from connectionId: UUID) throws -> EventSyncHandlingResult {
        switch event {
        case .write(let path, let data) where path.isEmpty:
            value = try context.decode(data: data, as: Array<Element>.self)
            return .alertRemainingConnections
        case .write(let path, let data):
            guard case .some(.index(let index)) = path.first else {
                throw ArrayEventHandlingError.expectedIntIndexInPathButReceivedSomethingElse
            }
            if value.indices.contains(index) {
                return try elementStrategy.handle(event: event.oneLevelLower(), with: context, for: &value[index], from: connectionId)
            } else if value.endIndex == index && path.count == 1 {
                value.append(try context.decode(data: data, as: Element.self))
                return .alertRemainingConnections
            } else {
                throw ArrayEventHandlingError.intIndexReceivedOutOfBounds(index)
            }
        case .delete(let path) where path.isEmpty:
            throw ArrayEventHandlingError.deletionOfWholeArrayNotAllowed
        case .delete(let path) where path.count == 1:
            guard case .some(.index(let index)) = path.first else {
                throw ArrayEventHandlingError.expectedIntIndexInPathButReceivedSomethingElse
            }
            guard value.indices.contains(index) else {
                throw ArrayEventHandlingError.intIndexReceivedOutOfBounds(index)
            }
            var value = value
            value.remove(at: index)
            return .alertRemainingConnections
        case .delete(let path):
            guard case .some(.index(let index)) = path.first else {
                throw ArrayEventHandlingError.expectedIntIndexInPathButReceivedSomethingElse
            }
            guard value.indices.contains(index) else {
                throw ArrayEventHandlingError.intIndexReceivedOutOfBounds(index)
            }
            return try elementStrategy.handle(event: event.oneLevelLower(), with: context, for: &value[index], from: connectionId)
        }
    }

    func events(from previous: [Element], to next: [Element], with context: EventCodingContext, from connectionId: UUID) -> [InternalEvent] {
        // TODO: More complex handling
        guard let data = try? context.encode(next) else { return [] }
        return [.write([], data)]
    }

    func subEvents(for value: [Element], with context: EventCodingContext, from connectionId: UUID) -> AnyPublisher<InternalEvent, Never> {
        let publishers = value.enumerated().map { item -> AnyPublisher<InternalEvent, Never> in
            let (offset, element) = item
            return self.elementStrategy.subEvents(for: element, with: context, from: connectionId)
                .map { $0.prefix(by: offset) }.eraseToAnyPublisher()
        }
        return Publishers.MergeMany(publishers).eraseToAnyPublisher()
    }
}

extension Array: HasErasedSyncStrategy where Element: Codable {}

extension Array: SyncableType where Element: Codable {
    static var strategy: ArrayStrategy<Element> {
        return ArrayStrategy(extractStrategy(for: Element.self))
    }
}
