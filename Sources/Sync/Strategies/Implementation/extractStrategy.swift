
import Foundation

func extractStrategy<T : Codable>(for type: T.Type) -> AnySyncStrategy<T> {
    if let type = type as? HasErasedSyncStrategy.Type {
        return type.erasedStrategy.read()
    }

    return AnySyncStrategy(CodableStrategy())
}
