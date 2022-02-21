
import Foundation

func extractStrategy<T : Codable>(for type: T.Type) -> AnySyncStrategy<T> {
    if let type = type as? HasErasedSyncStrategy.Type {
        return type.erasedStrategy.read()
    }

    if let type = type as? SyncableObject.Type {
        return type.erasedStrategy.read()
    }

    return AnySyncStrategy(CodableStrategy())
}

extension SyncableObject {

    static var erasedStrategy: ErasedSyncStrategy {
        return ErasedSyncStrategy(SyncableObjectStrategy<Self>())
    }

}
