
import Foundation

extension ReconnectionStrategy where Self == TryAgainReconnectionStrategy {
    public static func tryAgain(delay: TimeInterval) -> ReconnectionStrategy {
        return TryAgainReconnectionStrategy(delay: delay)
    }
}

public struct TryAgainReconnectionStrategy: ReconnectionStrategy {
    private let delay: TimeInterval

    public init(delay: TimeInterval) {
        self.delay = delay
    }

    public func maybeReconnect() async -> ReconnectionDecision {
        do {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            return .attemptToReconnect
        } catch {
            return .attemptToReconnect
        }
    }
}
