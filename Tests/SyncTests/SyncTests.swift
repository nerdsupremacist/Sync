import XCTest
@testable import Sync
import OpenCombineShim

class MockServerConnection: ProducerConnection {
    var isConnected: Bool {
        return true
    }

    var isConnectedPublisher: AnyPublisher<Bool, Never> {
        return Empty().eraseToAnyPublisher()
    }

    let codingContext: EventCodingContext = .json
    private let inputSubject = PassthroughSubject<Data, Never>()
    private let outputSubject = PassthroughSubject<Data, Never>()

    func disconnect() {
        fatalError()
    }

    func send(data: Data) {
        outputSubject.send(data)
    }

    func receive() -> AnyPublisher<Data, Never> {
        return inputSubject.eraseToAnyPublisher()
    }

    func dataForClient() -> AnyPublisher<Data, Never> {
        return outputSubject.eraseToAnyPublisher()
    }

    func clientSent(data: Data) {
        inputSubject.send(data)
    }
}

class MockClientConnection: ConsumerConnection {
    let codingContext: EventCodingContext = .json
    let service: MockRemoteService
    var serverConnection: MockServerConnection? = nil

    init(service: MockRemoteService) {
        self.service = service
    }

    var isConnected: Bool {
        return serverConnection != nil
    }

    var isConnectedPublisher: AnyPublisher<Bool, Never> {
        return Empty().eraseToAnyPublisher()
    }

    func connect() async throws -> Data {
        let response = try await service.createConnection()
        self.serverConnection = response.connection
        return response.data
    }

    func disconnect() {
        serverConnection?.disconnect()
    }

    func receive() -> AnyPublisher<Data, Never> {
        return serverConnection?.dataForClient() ?? Just(Data()).eraseToAnyPublisher()
    }

    func send(data: Data) {
        serverConnection?.clientSent(data: data)
    }
}

struct MockResponse {
    let data: Data
    let connection: MockServerConnection
}

class MockRemoteService {
    var managers: [SyncManager<ViewModel>] = []
    let viewModel: ViewModel

    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }

    func createConnection() async throws -> MockResponse {
        let connection = MockServerConnection()
        let manager = viewModel.sync(with: connection)
        managers.append(manager)
        return MockResponse(data: try manager.data(), connection: connection)
    }
}

class ViewModel: SyncableObject, Codable {
    class SubViewModel: SyncableObject, Codable {
        @Synced
        var toggle = false
    }

    @Synced
    var name = "Hello World!"

    @Synced
    var names = ["A", "B"]

    @Synced
    var subViewModels = [SubViewModel(), SubViewModel()]
}

final class SyncTests: XCTestCase {
    func testExample() async throws {
        let serverViewModel = ViewModel()
        let service = MockRemoteService(viewModel: serverViewModel)
        let clientConnection = MockClientConnection(service: service)
        let clientManager = try await ViewModel.sync(with: clientConnection)
        let clientViewModel = try clientManager.value()

        XCTAssertEqual(clientViewModel.name, "Hello World!")
        clientViewModel.name = "Foo"
        XCTAssertEqual(serverViewModel.name, "Foo")

        serverViewModel.name = "Bar"
        XCTAssertEqual(clientViewModel.name, "Bar")

        serverViewModel.subViewModels[0].toggle = true
        XCTAssertEqual(clientViewModel.subViewModels[0].toggle, true)
        XCTAssertEqual(clientViewModel.subViewModels[1].toggle, false)

        serverViewModel.names.insert("C", at: 1)
        XCTAssertEqual(clientViewModel.names[0], "A")
        XCTAssertEqual(clientViewModel.names[1], "C")
        XCTAssertEqual(clientViewModel.names[2], "B")
    }

    func testMultipleClients() async throws {
        let serverViewModel = ViewModel()
        let service1 = MockRemoteService(viewModel: serverViewModel)
        let service2 = MockRemoteService(viewModel: serverViewModel)
        let clientConnection1 = MockClientConnection(service: service1)
        let clientConnection2 = MockClientConnection(service: service2)
        let clientManager1 = try await ViewModel.sync(with: clientConnection1)
        let clientManager2 = try await ViewModel.sync(with: clientConnection2)
        let clientViewModel1 = try clientManager1.value()
        let clientViewModel2 = try clientManager2.value()

        XCTAssertEqual(clientViewModel1.name, "Hello World!")
        XCTAssertEqual(clientViewModel2.name, "Hello World!")
        clientViewModel1.name = "Foo"
        XCTAssertEqual(serverViewModel.name, "Foo")
        XCTAssertEqual(clientViewModel2.name, "Foo")

        clientViewModel2.names.insert("C", at: 1)
        XCTAssertEqual(clientViewModel1.names[0], "A")
        XCTAssertEqual(clientViewModel1.names[1], "C")
        XCTAssertEqual(clientViewModel1.names[2], "B")
    }
}
