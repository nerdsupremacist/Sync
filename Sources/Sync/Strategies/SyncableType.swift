
import Foundation

protocol SyncableType: HasErasedSyncStrategy {
    associatedtype Strategy: SyncStrategy where Strategy.Value == Self

    static var strategy: Strategy { get }
}

extension SyncableType {
    static var erasedStrategy: ErasedSyncStrategy {
        return ErasedSyncStrategy(strategy)
    }
}
