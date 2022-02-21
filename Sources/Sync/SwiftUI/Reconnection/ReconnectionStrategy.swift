
import Foundation

public enum ReconnectionDecision {
    case attemptToReconnect
    case stop
}

public protocol ReconnectionStrategy {
    func maybeReconnect() async -> ReconnectionDecision
}
