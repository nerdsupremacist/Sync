
import Foundation
@_exported import OpenCombineShim

class StringStrategy: SyncStrategy {
    enum StringEventHandlingError: Error {
        case expectedIntIndexInPathButReceivedSomethingElse
        case intIndexReceivedOutOfBounds(Int)
        case deletionOfEntireStringNotAllowed
        case deletionOfSubIndexNotAllowed
        case writingToSubIndexNotAllowed
        case insertingToSubIndexNotAllowed
        case deletionOfNegativeWidthNotAllowed
    }

    typealias Value = String

    init() { }

    func handle(event: InternalEvent, from context: ConnectionContext, for value: inout String) throws -> EventSyncHandlingResult {
        switch event {
        case .insert(let path, let offset, let data) where path.isEmpty:
            let index = value.index(value.startIndex, offsetBy: offset)
            guard value.indices.contains(index) || value.endIndex == index else {
                throw StringEventHandlingError.intIndexReceivedOutOfBounds(offset)
            }
            let string = try context.codingContext.decode(data: data, as: String.self)
            value.insert(contentsOf: string, at: index)
        case .write(let path, let data) where path.isEmpty:
            value = try context.codingContext.decode(data: data, as: String.self)
            return .alertRemainingConnections
        case .write(let path, let data) where path.count == 1:
            guard case .some(.index(let offset)) = path.first else {
                throw StringEventHandlingError.expectedIntIndexInPathButReceivedSomethingElse
            }
            let index = value.index(value.startIndex, offsetBy: offset)
            if value.indices.contains(index) {

            } else if value.endIndex == index && path.count == 1 {
                value.append(try context.codingContext.decode(data: data, as: String.self))
            } else {
                throw StringEventHandlingError.intIndexReceivedOutOfBounds(offset)
            }
        case .delete(let path, let width) where path.count == 1:
            guard case .some(.index(let offset)) = path.first else {
                throw StringEventHandlingError.expectedIntIndexInPathButReceivedSomethingElse
            }
            guard width != 0 else { return .done }
            guard width > 0 else { throw StringEventHandlingError.deletionOfNegativeWidthNotAllowed }

            let start = value.index(value.startIndex, offsetBy: offset)
            let end = value.index(start, offsetBy: width)
            let range = start..<end
            guard value.indices.contains(start), value.indices.contains(value.index(before: end)) else {
                throw StringEventHandlingError.intIndexReceivedOutOfBounds(offset)
            }

            value.removeSubrange(range)
        case .delete(let path, _) where path.isEmpty:
            throw StringEventHandlingError.deletionOfEntireStringNotAllowed
        case .delete:
            throw StringEventHandlingError.deletionOfSubIndexNotAllowed
        case .write:
            throw StringEventHandlingError.deletionOfSubIndexNotAllowed
        case .insert:
            throw StringEventHandlingError.deletionOfSubIndexNotAllowed
        }
        return .alertRemainingConnections
    }

    func events(from previous: String, to next: String, for context: ConnectionContext) -> [InternalEvent] {
        let differences = next.stringDifference(from: previous)
        let isWritingWholeValue = differences.contains { change in
            switch change {
            case .insert(_, let element, _):
                return element == next
            case .remove(_, let element, _):
                return element == previous
            }
        }
        guard differences.count < next.count, !isWritingWholeValue else {
            guard let data = try? context.codingContext.encode(next) else { return [] }
            return [.write([], data)]
        }

        return differences.compactMap { operation in
            switch operation {
            case .insert(let offset, let element, _):
                guard let data = try? context.codingContext.encode(element) else { return nil }
                return .insert([], index: offset, data)
            case .remove(offset: let offset, let element, _):
                return .delete([.index(offset)], width: element.count)
            }
        }
    }

    func subEvents(for value: String, for context: ConnectionContext) -> AnyPublisher<InternalEvent, Never> {
        return Empty(completeImmediately: false).eraseToAnyPublisher()
    }
}

extension String: SyncableType {
    static let strategy: StringStrategy = StringStrategy()
}

extension String {

    fileprivate func stringDifference(from previous: String) -> CollectionDifference<String> {
        var changes: [CollectionDifference<String>.Change] = []
        var current: CollectionDifference<String>.Change?

        for change in difference(from: previous) {
            switch (current, change) {
            case (.some(.insert(let lhsOffset, let lhsElement, let lhsWidth)), .insert(let rhsOffset, let rhsElement, let rhsWidth)) where (lhsOffset + lhsElement.count) == rhsOffset:
                current = .insert(offset: lhsOffset, element: lhsElement + String(rhsElement), associatedWith: lhsWidth + rhsWidth)
            case (.some(.remove(let lhsOffset, let lhsElement, let lhsWidth)), .remove(let rhsOffset, let rhsElement, let rhsWidth)) where (lhsOffset + lhsElement.count) == rhsOffset:
                current = .remove(offset: lhsOffset, element: lhsElement + String(rhsElement), associatedWith: lhsWidth + rhsWidth)
            case (.some(.insert(let lhsOffset, let lhsElement, let lhsWidth)), .insert(let rhsOffset, let rhsElement, let rhsWidth)) where (rhsOffset + 1) == lhsOffset:
                current = .insert(offset: rhsOffset, element: String(rhsElement) + lhsElement, associatedWith: lhsWidth + rhsWidth)
            case (.some(.remove(let lhsOffset, let lhsElement, let lhsWidth)), .remove(let rhsOffset, let rhsElement, let rhsWidth)) where (rhsOffset + 1) == lhsOffset:
                current = .remove(offset: rhsOffset, element: String(rhsElement) + lhsElement, associatedWith: lhsWidth + rhsWidth)
            case (_, .remove(let offset, let element, let width)):
                if let current = current {
                    changes.append(current)
                }
                current = .remove(offset: offset, element: String(element), associatedWith: width)
            case (_, .insert(let offset, let element, let width)):
                if let current = current {
                    changes.append(current)
                }
                current = .insert(offset: offset, element: String(element), associatedWith: width)
            }
        }

        if let current = current {
            changes.append(current)
        }

        return CollectionDifference(changes)!
    }
}

fileprivate func + (lhs: Int?, rhs: Int?) -> Int? {
    switch (lhs, rhs) {
    case (.some(let lhs), .some(let rhs)):
        return lhs + rhs
    case (_, .none):
        return lhs
    case (.none, _):
        return rhs
    }
}
