
import Foundation

#if canImport(SwiftUI)
import SwiftUI

public struct Sync<Value : SyncedObject, Content : View>: View {
    @StateObject
    private var viewModel: SyncViewModel<Value>
    private let content: (SyncedObservedObject<Value>) -> Content

    public init(_ type: Value.Type, using connection: ConsumerConnection, @ViewBuilder content: @escaping (SyncedObservedObject<Value>) -> Content) {
        self._viewModel = StateObject(wrappedValue: SyncViewModel(connection: connection))
        self.content = content
    }

    public init(_ type: Value.Type, using syncManager: SyncManager<Value>, @ViewBuilder content: @escaping (SyncedObservedObject<Value>) -> Content) {
        self._viewModel = StateObject(wrappedValue: SyncViewModel(syncManager: syncManager))
        self.content = content
    }

    public var body: some View {
        if let synced = viewModel.synced {
            content(synced)
        } else if let error = viewModel.error {
            Text(error.localizedDescription)
        } else {
            Text("Loading...")
                .onAppear {
                    Task {
                        await viewModel.loadIfNeeded()
                    }
                }
        }
    }
}

fileprivate class SyncViewModel<Value : SyncedObject>: ObservableObject {
    private enum State {
        case loading(ConsumerConnection)
        case synced(SyncedObservedObject<Value>)
    }

    @Published
    private var state: State

    @Published
    private var isLoading: Bool = false

    @Published
    private(set) var error: Error?

    var synced: SyncedObservedObject<Value>? {
        switch state {
        case .synced(let object):
            return object
        case .loading:
            return nil
        }
    }

    init(connection: ConsumerConnection) {
        self.state = .loading(connection)
    }

    init(syncManager: SyncManager<Value>) {
        self.state = .synced(try! SyncedObservedObject(syncManager: syncManager))
    }

    func loadIfNeeded() async {
        switch state {
        case .synced:
            return
        case .loading(let connection):
            guard !isLoading else { return }
            isLoading = true
            do {
                let manager = try await Value.manager(with: connection)
                let state: State = await .synced(try SyncedObservedObject(syncManager: manager))
                DispatchQueue.main.async { [weak self] in
                    self?.state = state
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.isLoading = false
                    self?.error = error
                }
            }
        }
    }
}
#endif
