import XCTest
@testable import Sync
import Combine

class MockServerConnection: ProducerConnection {
    var isConnected: Bool {
        return true
    }

    let codingContext: EventCodingContext = JSONEventCodingContext()
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
    let codingContext: EventCodingContext = JSONEventCodingContext()
    let service: MockRemoteService
    var serverConnection: MockServerConnection? = nil

    init(service: MockRemoteService) {
        self.service = service
    }

    var isConnected: Bool {
        return serverConnection != nil
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
        let manager = viewModel.manager(with: connection)
        managers.append(manager)
        return MockResponse(data: try manager.data(), connection: connection)
    }
}

class ViewModel: SyncedObject, Codable {
    class SubViewModel: SyncedObject, Codable {
        @Synced
        var toggle = false
    }

    @Synced
    var name = "Hello World!"

    @Synced
    var subViewModels = [SubViewModel(), SubViewModel()]
}

final class SyncTests: XCTestCase {
    func testExample() async throws {
        let serverViewModel = ViewModel()
        let service = MockRemoteService(viewModel: serverViewModel)
        let clientConnection = MockClientConnection(service: service)
        let clientManager = try await ViewModel.manager(with: clientConnection)
        let clientViewModel = try clientManager.value()

        XCTAssertEqual(clientViewModel.name, "Hello World!")
        clientViewModel.name = "Foo"
        XCTAssertEqual(serverViewModel.name, "Foo")

        serverViewModel.name = "Bar"
        XCTAssertEqual(clientViewModel.name, "Bar")

        serverViewModel.subViewModels[0].toggle = true
        XCTAssertEqual(clientViewModel.subViewModels[0].toggle, true)
        XCTAssertEqual(clientViewModel.subViewModels[1].toggle, false)
    }
}
