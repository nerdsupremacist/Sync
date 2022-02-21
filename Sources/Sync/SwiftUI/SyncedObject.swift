
#if canImport(SwiftUI)
import SwiftUI
import Combine

@dynamicMemberLookup
@propertyWrapper
public struct SyncedObject<Value : SyncableObject>: DynamicProperty {
    private class Storage {
        var value: Value

        init(value: Value) {
            self.value = value
        }
    }

    @ObservedObject
    private var fakeObservable: FakeObservableObject

    private let manager: AnyManager
    private let storage: Storage

    public var wrappedValue: Value {
        get {
            return storage.value
        }
    }

    private init(value: Value, manager: AnyManager) {
        self.fakeObservable = FakeObservableObject(manager: manager)
        self.storage = Storage(value: value)
        self.manager = manager
    }

    init(syncManager: SyncManager<Value>) throws {
        self.init(value: try syncManager.value(), manager: Manager(manager: syncManager))
    }

    func forceUpdate(value: Value) {
        self.storage.value = value
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
        return SyncedObject<Subject>(value: storage.value[keyPath: keyPath], manager: manager)
    }

    public subscript<Subject : Codable>(dynamicMember keyPath: WritableKeyPath<Value, Subject>) -> Binding<Subject> {
        return Binding(get: { self.storage.value[keyPath: keyPath] }, set: { self.storage.value[keyPath: keyPath] = $0 })
    }

}

private final class FakeObservableObject: ObservableObject {
    typealias ObjectWillChangePublisher = AnyPublisher<Void, Never>

    private let manualUpdate = PassthroughSubject<Void, Never>()
    private let manager: AnyManager

    let objectWillChange: AnyPublisher<Void, Never>

    init(manager: AnyManager) {
        self.manager = manager
        let changeEvents = manager.eventHasChanged
        let connectionChange = manager.connection.isConnectedPublisher.removeDuplicates().map { _ in () }

        objectWillChange = changeEvents
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
