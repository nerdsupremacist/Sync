
import Foundation
import OpenCombineShim

public protocol SyncedObject: AnyObject, Codable { }

extension SyncedObject {
    public func manager(with connection: ProducerConnection) -> SyncManager<Self> {
        return SyncManager(self, connection: connection)
    }

    public func managerWithoutRetainingInMemory(with connection: ProducerConnection) -> SyncManager<Self> {
        return SyncManager(weak: self, connection: connection)
    }

    public static func manager(with connection: ConsumerConnection) async throws -> SyncManager<Self> {
        let data = try await connection.connect()
        let value = try connection.codingContext.decode(data: data, as: Self.self)
        return SyncManager(value, connection: connection)
    }
}
