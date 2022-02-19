
import Foundation
import Combine

class SyncedObjectStrategy<Value: SyncedObject>: SyncStrategy {
    enum ObjectEventHandlingError: Error {
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

    func handle(event: InternalEvent, with context: EventCodingContext, for value: inout Value) throws {
        switch event {
        case .delete(let path) where path.isEmpty:
            throw ObjectEventHandlingError.cannotDeleteSyncedObject
        case .delete(let path), .write(let path, _):
            let strategiesPerPath = computeStrategies(for: value)
            guard case .some(.name(let label)) = path.first else {
                throw ObjectEventHandlingError.pathForObjectWasNotAStringLabel
            }
            guard let strategy = strategiesPerPath[label] else {
                throw ObjectEventHandlingError.syncedPropertyForLabelNotFound(label)
            }
            try strategy.handle(event: event.oneLevelLower(), with: context)
        }
    }

    func events(for value: AnyPublisher<Value, Never>, with context: EventCodingContext) -> AnyPublisher<InternalEvent, Never> {
        return value
            .flatMap { [unowned self] value -> AnyPublisher<InternalEvent, Never> in
                let strategiesPerPath = self.computeStrategies(for: value)
                let publishers = strategiesPerPath.map { item -> AnyPublisher<InternalEvent, Never> in
                    let (label, strategy) = item
                    return strategy.events(with: context).map { $0.prefix(by: label) }.eraseToAnyPublisher()
                }

                return Publishers.MergeMany(publishers).eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
}