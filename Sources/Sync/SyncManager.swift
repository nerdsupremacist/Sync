
import Foundation
import OpenCombineShim

public class SyncManager<Value: SyncableObject> {
    enum SyncManagerError: Error {
        case unretainedValueWasReleased
    }

    private class BaseStorage {
        var object: Value? {
            return nil
        }

        func set(value: Value) {
            fatalError()
        }
    }

    private final class RetainedStorage: BaseStorage {
        private var value: Value

        init(value: Value) {
            self.value = value
        }

        override var object: Value? {
            return value
        }

        override func set(value: Value) {
            self.value = value
        }
    }

    private final class WeakStorage: BaseStorage {
        private weak var value: Value?

        init(value: Value) {
            self.value = value
        }

        override var object: Value? {
            return value
        }

        override func set(value: Value) {
            self.value = value
        }
    }

    private let id = UUID()
    private let strategy: AnySyncStrategy<Value>
    private let storage: BaseStorage
    public let connection: Connection
    private var cancellables: Set<AnyCancellable> = []
    private let errorsSubject = PassthroughSubject<Error, Never>()
    private let hasChangedSubject = PassthroughSubject<Void, Never>()

    public var isConnected: Bool {
        return connection.isConnected
    }

    public var eventHasChanged: AnyPublisher<Void, Never> {
        return hasChangedSubject.eraseToAnyPublisher()
    }

    init(_ value: Value, connection: Connection) {
        self.strategy = extractStrategy(for: Value.self)
        self.storage = RetainedStorage(value: value)
        self.connection = connection
        setUpConnection()
    }

    init(weak value: Value, connection: Connection) {
        self.strategy = extractStrategy(for: Value.self)
        self.storage = WeakStorage(value: value)
        self.connection = connection
        setUpConnection()
    }

    public func value() throws -> Value {
        guard let value = storage.object else {
            throw SyncManagerError.unretainedValueWasReleased
        }
        return value
    }

    public func data() throws -> Data {
        return try connection.codingContext.encode(try value())
    }

    @discardableResult
    public func reconnect() async throws -> Bool {
        guard let connection = connection as? ConsumerConnection else {
            return false
        }

        if connection.isConnected {
            connection.disconnect()
        }
        let data = try await connection.connect()
        do {
            let value = try connection.codingContext.decode(data: data, as: Value.self)
            storage.set(value: value)
            setUpConnection()
            hasChangedSubject.send()
            return true
        } catch {
            connection.disconnect()
            throw error
        }
    }
    
    private func setUpConnection() {
        cancellables = []
        connection
            .receive()
            .sink { [unowned self] data in
                do {
                    var value = try self.value()
                    let event = try self.connection.codingContext.decode(data: data, as: InternalEvent.self)
                    _ = try self.strategy.handle(event: event, with: self.connection.codingContext, for: &value, from: self.id)
                    self.hasChangedSubject.send()
                } catch {
                    self.errorsSubject.send(error)
                }
            }
            .store(in: &cancellables)

        guard let value = storage.object else { return }
        strategy
            .subEvents(for: value,
                    with: connection.codingContext,
                    from: self.id)
            .sink { [unowned self] event in
                do {
                    self.hasChangedSubject.send()
                    let data = try self.connection.codingContext.encode(event)
                    self.connection.send(data: data)
                } catch {
                    self.errorsSubject.send(error)
                }
            }
            .store(in: &cancellables)
    }
}
