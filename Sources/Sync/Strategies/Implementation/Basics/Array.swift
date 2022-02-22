
import Foundation
import OpenCombineShim

class ArrayStrategy<Element : Codable>: SyncStrategy {
    enum ArrayEventHandlingError: Error {
        case expectedIntIndexInPathButReceivedSomethingElse
        case intIndexReceivedOutOfBounds(Int)
        case deletionOfWholeArrayNotAllowed
    }

    typealias Value = [Element]

    let elementStrategy: AnySyncStrategy<Element>
    let equivalenceDetector: AnyEquivalenceDetector<Element>?

    init(_ elementStrategy: AnySyncStrategy<Element>, equivalenceDetector: AnyEquivalenceDetector<Element>?) {
        self.elementStrategy = elementStrategy
        self.equivalenceDetector = equivalenceDetector
    }

    func handle(event: InternalEvent, with context: EventCodingContext, for value: inout [Element], from connectionId: UUID) throws -> EventSyncHandlingResult {
        switch event {
        case .insert(let path, let index, let data) where path.isEmpty:
            guard value.indices.contains(index) || value.endIndex == index else {
                throw ArrayEventHandlingError.intIndexReceivedOutOfBounds(index)
            }
            let element = try context.decode(data: data, as: Element.self)
            value.insert(element, at: index)
            return .alertRemainingConnections
        case .write(let path, let data) where path.isEmpty:
            value = try context.decode(data: data, as: Array<Element>.self)
            return .alertRemainingConnections
        case .insert(let path, _, _):
            guard case .some(.index(let index)) = path.first else {
                throw ArrayEventHandlingError.expectedIntIndexInPathButReceivedSomethingElse
            }
            if value.indices.contains(index) {
                return try elementStrategy.handle(event: event.oneLevelLower(), with: context, for: &value[index], from: connectionId)
            } else {
                throw ArrayEventHandlingError.intIndexReceivedOutOfBounds(index)
            }
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
        guard let equivalenceDetector = equivalenceDetector else {
            guard let data = try? context.encode(next) else { return [] }
            return [.write([], data)]
        }

        let differences = next.difference(from: previous) { equivalenceDetector.areEquivalent(lhs: $0, rhs: $1) }
        guard differences.count < next.count else {
            guard let data = try? context.encode(next) else { return [] }
            return [.write([], data)]
        }

        return differences.compactMap { operation in
            switch operation {
            case .insert(let offset, let element, _):
                guard let data = try? context.encode(element) else { return nil }
                return .insert([], index: offset, data)
            case .remove(offset: let offset, _, _):
                return .delete([.index(offset)])
            }
        }
    }

    func subEvents(for value: [Element], with context: EventCodingContext, from connectionId: UUID) -> AnyPublisher<InternalEvent, Never> {
        return value
            .enumerated()
            .map { item -> AnyPublisher<InternalEvent, Never> in
                let (offset, element) = item
                return self.elementStrategy.subEvents(for: element, with: context, from: connectionId)
                    .map { $0.prefix(by: offset) }.eraseToAnyPublisher()
            }
            .mergeMany()
    }
}

extension Array: HasErasedSyncStrategy where Element: Codable {}

extension Array: SyncableType where Element: Codable {
    static var strategy: ArrayStrategy<Element> {
        let equivalenceDetector = extractEquivalenceDetector(for: Element.self)
        return ArrayStrategy(extractStrategy(for: Element.self), equivalenceDetector: equivalenceDetector)
    }
}
