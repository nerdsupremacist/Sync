
#if canImport(SwiftUI)
import SwiftUI
import Combine

@propertyWrapper
public struct SyncedObservedObject<Value : SyncedObject>: DynamicProperty {
    private class FakeObservableObject: ObservableObject {
        private let syncManager: SyncManager<Value>

        init(syncManager: SyncManager<Value>) {
            self.syncManager = syncManager
        }

        var objectWillChange: AnyPublisher<Void, Never> {
            return syncManager
                .eventHasChanged
                .receive(on: DispatchQueue.main)
                .eraseToAnyPublisher()
        }
    }

    @ObservedObject
    private var fakeObservable: FakeObservableObject

    private let syncManager: SyncManager<Value>
    private let value: Value

    public var wrappedValue: Value {
        get {
            return value
        }
    }

    init(syncManager: SyncManager<Value>) throws {
        self.fakeObservable = FakeObservableObject(syncManager: syncManager)
        self.syncManager = syncManager
        self.value = try syncManager.value()
    }

    public var projectedValue: SyncManager<Value> {
        return syncManager
    }
}

#endif
