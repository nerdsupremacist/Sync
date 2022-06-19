
import Foundation
@_implementationOnly import MessagePack

extension EventCodingContext where Self == MessagePackEventCodingContext {

    public static var messagePack: EventCodingContext {
        return MessagePackEventCodingContext()
    }

    public static var `default`: EventCodingContext {
        return .messagePack
    }

}

public struct MessagePackEventCodingContext: EventCodingContext {
    private let encoder = MessagePackEncoder()
    private let decoder = MessagePackDecoder()

    public init() { }

    public func decode<T>(data: Data, as type: T.Type) throws -> T where T : Decodable {
        return try decoder.decode(type, from: data)
    }

    public func encode<T>(_ value: T) throws -> Data where T : Encodable {
        return try encoder.encode(value)
    }
}
