
import Foundation
import OpenCombineShim

public protocol SyncableObject: AnyObject, Codable { }

extension SyncableObject {
    public func sync(with connection: ProducerConnection) -> SyncManager<Self> {
        return SyncManager(self, connection: connection)
    }

    public func syncWithoutRetainingInMemory(with connection: ProducerConnection) -> SyncManager<Self> {
        return SyncManager(weak: self, connection: connection)
    }

    public static func sync(with connection: ConsumerConnection) async throws -> SyncManager<Self> {
        let data = try await connection.connect()
        do {
            let value = try connection.codingContext.decode(data: data, as: Self.self)
            return SyncManager(value, connection: connection)
        } catch {
            connection.disconnect()
            throw error
        }
    }
}
