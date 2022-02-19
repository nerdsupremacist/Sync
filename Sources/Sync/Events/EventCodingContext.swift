
import Foundation

public protocol EventCodingContext {
    func decode<T : Decodable>(data: Data, as type: T.Type) throws -> T
    func encode<T : Encodable>(_ value: T) throws -> Data
}

public struct JSONEventCodingContext: EventCodingContext {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init() { }

    public func decode<T>(data: Data, as type: T.Type) throws -> T where T : Decodable {
        return try decoder.decode(type, from: data)
    }

    public func encode<T>(_ value: T) throws -> Data where T : Encodable {
        return try encoder.encode(value)
    }
}
