
import Foundation
@_exported import OpenCombineShim

class SyncableObjectStrategy<Value: SyncableObject>: SyncStrategy {
    enum ObjectEventHandlingError: Error {
        case cannotHandleInsertion
        case cannotDeleteSyncedObject
        case pathForObjectWasNotAStringLabel
        case syncedPropertyForLabelNotFound(String)
    }

    var identifier: ObjectIdentifier?
    var strategiesPerPath: [String : SelfContainedStrategy]? = nil

    init() {}

    private func computeStrategies(for value: Value) -> [String : SelfContainedStrategy] {
        if let strategiesPerPath = strategiesPerPath, let identifier = identifier, identifier == ObjectIdentifier(value) {
            return strategiesPerPath
        }

        var strategiesPerPath = [String : SelfContainedStrategy]()
        let mirror = Mirror(reflecting: value)
        for child in mirror.children {
            guard let label = child.label, let value = child.value as? SelfContainedStrategy else { continue }
            strategiesPerPath[label] = value
        }

        self.strategiesPerPath = strategiesPerPath
        return strategiesPerPath
    }

    func handle(event: InternalEvent, from context: ConnectionContext, for value: inout Value) throws -> EventSyncHandlingResult {
        switch event {
        case .insert(let path, _, _) where path.isEmpty:
            throw ObjectEventHandlingError.cannotHandleInsertion
        case .delete(let path) where path.isEmpty:
            throw ObjectEventHandlingError.cannotDeleteSyncedObject
        case .delete(let path), .write(let path, _), .insert(let path, _, _):
            let strategiesPerPath = computeStrategies(for: value)
            guard case .some(.name(let label)) = path.first else {
                throw ObjectEventHandlingError.pathForObjectWasNotAStringLabel
            }
            guard let strategy = strategiesPerPath[label] else {
                throw ObjectEventHandlingError.syncedPropertyForLabelNotFound(label)
            }
            try strategy.handle(event: event.oneLevelLower(), from: context)
            return .done
        }
    }

    func events(from previous: Value, to next: Value, for context: ConnectionContext) -> [InternalEvent] {
        guard let data = try? context.codingContext.encode(next) else { return [] }
        return [.write([], data)]
    }

    func subEvents(for value: Value, for context: ConnectionContext) -> AnyPublisher<InternalEvent, Never> {
        return computeStrategies(for: value)
            .map { item -> AnyPublisher<InternalEvent, Never> in
                let (label, strategy) = item
                return strategy.events(for: context).map { $0.prefix(by: label) }.eraseToAnyPublisher()
            }
            .mergeMany()
    }
}
