
import Foundation

public protocol EventCodingContext {
    func decode<T : Decodable>(data: Data, as type: T.Type) throws -> T
    func encode<T : Encodable>(_ value: T) throws -> Data
}
