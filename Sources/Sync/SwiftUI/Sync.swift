
#if canImport(SwiftUI)
import SwiftUI
@_exported import OpenCombineShim

public struct Sync<Value : SyncableObject, Content : View, LoadingView : View, ErrorView : View>: View {
    @StateObject
    private var viewModel: SyncViewModel<Value>
    private let loading: LoadingView
    private let error: (Error) -> ErrorView
    private let content: (SyncedObject<Value>) -> Content

    public init(_ type: Value.Type = Value.self,
                using connection: ConsumerConnection,
                reconnectionStrategy: ReconnectionStrategy? = nil,
                @ViewBuilder content: @escaping (SyncedObject<Value>) -> Content,
                @ViewBuilder loading: () -> LoadingView,
                @ViewBuilder error: @escaping (Error) -> ErrorView) {

        self._viewModel = StateObject(wrappedValue: SyncViewModel(connection: connection, reconnectionStrategy: reconnectionStrategy))
        self.loading = loading()
        self.error = error
        self.content = content
    }

    public var body: some View {
        if let synced = viewModel.synced {
            content(synced)
        } else if let error = viewModel.error {
            self.error(error)
        } else {
            loading
                .onAppear {
                    Task {
                        await viewModel.loadIfNeeded()
                    }
                }
        }
    }
}

extension Sync where LoadingView == AnyView {

    public init(_ type: Value.Type = Value.self,
                using connection: ConsumerConnection,
                reconnectionStrategy: ReconnectionStrategy? = nil,
                @ViewBuilder content: @escaping (SyncedObject<Value>) -> Content,
                @ViewBuilder error: @escaping (Error) -> ErrorView) {

        self.init(type,
                  using: connection,
                  reconnectionStrategy: reconnectionStrategy,
                  content: content,
                  loading: { AnyView(BasicLoadingView()) },
                  error: error)
    }

}

extension Sync where ErrorView == AnyView {


    public init(_ type: Value.Type = Value.self,
                using connection: ConsumerConnection,
                reconnectionStrategy: ReconnectionStrategy? = nil,
                @ViewBuilder content: @escaping (SyncedObject<Value>) -> Content,
                @ViewBuilder loading: () -> LoadingView) {

        self.init(type,
                  using: connection,
                  reconnectionStrategy: reconnectionStrategy,
                  content: content,
                  loading: loading,
                  error: { AnyView(BasicErrorView(error: $0)) })
    }

}

extension Sync where LoadingView == AnyView, ErrorView == AnyView {

    public init(_ type: Value.Type = Value.self,
                using connection: ConsumerConnection,
                reconnectionStrategy: ReconnectionStrategy? = nil,
                @ViewBuilder content: @escaping (SyncedObject<Value>) -> Content) {

        self.init(type,
                  using: connection,
                  reconnectionStrategy: reconnectionStrategy,
                  content: content,
                  loading: { AnyView(BasicLoadingView()) },
                  error: { AnyView(BasicErrorView(error: $0)) })
    }

    public init(_ type: Value.Type = Value.self,
                using syncManager: SyncManager<Value>,
                @ViewBuilder content: @escaping (SyncedObject<Value>) -> Content) {

        self._viewModel = StateObject(wrappedValue: SyncViewModel(syncManager: syncManager))
        self.content = content
        self.loading = AnyView(BasicLoadingView())
        self.error = { AnyView(BasicErrorView(error: $0)) }
    }

}

private struct BasicLoadingView: View {
    var body: some View {
        Text("Loading")
    }
}

private struct BasicErrorView: View {
    let error: Error

    var body: some View {
        Text("Error: \(error.localizedDescription)")
    }
}

fileprivate class SyncViewModel<Value : SyncableObject>: ObservableObject {
    private enum State {
        case loading(ConsumerConnection)
        case synced(SyncedObject<Value>)
    }

    @Published
    private var state: State

    @Published
    private var isLoading: Bool = false

    @Published
    private(set) var error: Error?

    private var cancellables: Set<AnyCancellable> = []
    private let reconnectionStrategy: ReconnectionStrategy?
    private var reconnectionTask: Task<Void, Never>? = nil

    var synced: SyncedObject<Value>? {
        switch state {
        case .synced(let object):
            return object
        case .loading:
            return nil
        }
    }

    init(connection: ConsumerConnection, reconnectionStrategy: ReconnectionStrategy?) {
        self.state = .loading(connection)
        self.reconnectionStrategy = reconnectionStrategy
    }

    init(syncManager: SyncManager<Value>) {
        self.state = .synced(try! SyncedObject(syncManager: syncManager))
        self.reconnectionStrategy = nil
    }

    deinit {
        reconnectionTask?.cancel()
    }

    func loadIfNeeded() async {
        switch state {
        case .synced:
            return
        case .loading(let connection):
            guard !isLoading else { return }
            isLoading = true
            do {
                reconnectionTask?.cancel()
                cancellables = []
                let manager = try await Value.sync(with: connection)
                // For some reason Swift says this needs an await ¯\_(ツ)_/¯
                let object = try await SyncedObject(syncManager: manager)

                if let reconnectionStrategy = reconnectionStrategy {
                    connection
                        .isConnectedPublisher
                        .removeDuplicates()
                        .filter { !$0 }
                        .receive(on: DispatchQueue.global())
                        .sink { [unowned self] _ in
                            self.reconnectionTask?.cancel()
                            self.reconnectionTask = Task { [unowned self] in
                                while case .attemptToReconnect = await reconnectionStrategy.maybeReconnect() {
                                    do {
                                        guard try await manager.reconnect() else { return }
                                        let updateTask = Task { @MainActor in
                                            object.forceUpdate(value: try manager.value())
                                        }
                                        try await updateTask.value
                                        return
                                    } catch {
                                        DispatchQueue.main.async { [weak self] in
                                            self?.error = error
                                        }
                                    }
                                }
                            }
                        }
                        .store(in: &cancellables)
                }
                let state: State = .synced(object)
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
