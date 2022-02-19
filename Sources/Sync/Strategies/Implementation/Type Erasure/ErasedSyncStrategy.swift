
import Foundation

protocol HasErasedSyncStrategy: Codable {
    static var erasedStrategy: ErasedSyncStrategy { get }
}

class ErasedSyncStrategy {
    private let strategy: Any

    init<Strategy: SyncStrategy>(_ strategy: Strategy) {
        self.strategy = AnySyncStrategy(strategy)
    }

    func read<Value>() -> AnySyncStrategy<Value> {
        guard let strategy = strategy as? AnySyncStrategy<Value> else { fatalError() }
        return strategy
    }
}
