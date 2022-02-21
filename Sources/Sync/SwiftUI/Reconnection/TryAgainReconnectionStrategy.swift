
import Foundation

extension ReconnectionStrategy where Self == TryAgainReconnectionStrategy {
    public static var tryAgain: ReconnectionStrategy {
        return TryAgainReconnectionStrategy()
    }

    public static func tryAgain(delay: TimeInterval) -> ReconnectionStrategy {
        return TryAgainReconnectionStrategy(delay: delay)
    }
}

public struct TryAgainReconnectionStrategy: ReconnectionStrategy {
    private let delay: TimeInterval?

    public init(delay: TimeInterval? = nil) {
        self.delay = delay
    }

    public func maybeReconnect() async -> ReconnectionDecision {
        guard let delay = delay else { return .attemptToReconnect }
        do {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            return .attemptToReconnect
        } catch {
            return .attemptToReconnect
        }
    }
}
