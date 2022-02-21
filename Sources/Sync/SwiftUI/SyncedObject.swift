
#if canImport(SwiftUI)
import SwiftUI
import Combine

@dynamicMemberLookup
@propertyWrapper
public class SyncedObject<Value : SyncableObject>: DynamicProperty {
    @ObservedObject
    private var fakeObservable: FakeObservableObject

    private let manager: AnyManager
    private var value: Value

    public var wrappedValue: Value {
        get {
            return value
        }
    }

    private init(value: Value, manager: AnyManager) {
        self.fakeObservable = FakeObservableObject(manager: manager)
        self.value = value
        self.manager = manager
    }

    convenience init(syncManager: SyncManager<Value>) throws {
        self.init(value: try syncManager.value(), manager: Manager(manager: syncManager))
    }

    func forceUpdate(value: Value) {
        self.value = value
        fakeObservable.forceUpdate()
    }
}

extension SyncedObject {

    public var projectedValue: SyncedObject<Value> {
        return self
    }

}

extension SyncedObject {

    public var connection: Connection {
        return manager.connection
    }

}

extension SyncedObject {

    public subscript<Subject : SyncableObject>(dynamicMember keyPath: KeyPath<Value, Subject>) -> SyncedObject<Subject> {
        return SyncedObject<Subject>(value: value[keyPath: keyPath], manager: manager)
    }

    public subscript<Subject : Codable>(dynamicMember keyPath: WritableKeyPath<Value, Subject>) -> Binding<Subject> {
        return Binding(get: { self.value[keyPath: keyPath] }, set: { self.value[keyPath: keyPath] = $0 })
    }

}

private final class FakeObservableObject: ObservableObject {
    private let manualUpdate = PassthroughSubject<Void, Never>()
    private let manager: AnyManager

    init(manager: AnyManager) {
        self.manager = manager
    }

    var objectWillChange: AnyPublisher<Void, Never> {
        let changeEvents = manager.eventHasChanged
        let connectionChange = manager.connection.isConnectedPublisher.removeDuplicates().map { _ in () }

        return changeEvents
            .merge(with: connectionChange)
            .merge(with: manualUpdate)
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    func forceUpdate() {
        manualUpdate.send()
    }
}

private class AnyManager {
    var connection: Connection {
        fatalError()
    }

    var eventHasChanged: AnyPublisher<Void, Never> {
        fatalError()
    }
}

private final class Manager<Root : SyncableObject>: AnyManager {
    let manager: SyncManager<Root>

    init(manager: SyncManager<Root>) {
        self.manager = manager
    }

    override var eventHasChanged: AnyPublisher<Void, Never> {
        return manager.eventHasChanged
    }

    override var connection: Connection {
        return manager.connection
    }
}
#endif
