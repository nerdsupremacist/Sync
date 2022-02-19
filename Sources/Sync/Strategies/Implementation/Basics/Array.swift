
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

    func handle(event: InternalEvent, with context: EventCodingContext, for value: inout [Element]) throws {
        switch event {
        case .write(let path, let data) where path.isEmpty:
            value = try context.decode(data: data, as: Array<Element>.self)
        case .write(let path, let data):
            guard case .some(.index(let index)) = path.first else {
                throw ArrayEventHandlingError.expectedIntIndexInPathButReceivedSomethingElse
            }
            if value.indices.contains(index) {
                try elementStrategy.handle(event: event.oneLevelLower(), with: context, for: &value[index])
            } else if value.endIndex == index && path.count == 1 {
                value.append(try context.decode(data: data, as: Element.self))
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
        case .delete(let path):
            guard case .some(.index(let index)) = path.first else {
                throw ArrayEventHandlingError.expectedIntIndexInPathButReceivedSomethingElse
            }
            guard value.indices.contains(index) else {
                throw ArrayEventHandlingError.intIndexReceivedOutOfBounds(index)
            }
            try elementStrategy.handle(event: event.oneLevelLower(), with: context, for: &value[index])
        }
    }

    func events(for value: AnyPublisher<[Element], Never>, with context: EventCodingContext) -> AnyPublisher<InternalEvent, Never> {
        return value.flatMap { elements -> AnyPublisher<InternalEvent, Never> in
            let publishers = elements.enumerated().map { item -> AnyPublisher<InternalEvent, Never> in
                let (offset, element) = item
                return self.elementStrategy.events(for: Just(element).eraseToAnyPublisher(), with: context).map { $0.prefix(by: offset) }.eraseToAnyPublisher()
            }
            return Publishers.MergeMany(publishers).eraseToAnyPublisher()
        }.eraseToAnyPublisher()
    }
}

extension Array: HasErasedSyncStrategy where Element: Codable {}

extension Array: SyncableType where Element: Codable {
    static var strategy: ArrayStrategy<Element> {
        return ArrayStrategy(extractStrategy(for: Element.self))
    }
}
