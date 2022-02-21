
import Foundation

struct EquatableEquivalenceDetector<Value: Equatable>: EquivalenceDetector {
    func areEquivalent(lhs: Value, rhs: Value) -> Bool {
        return lhs == rhs
    }
}
