
import Foundation

struct ReferenceEquivalenceDetector<Value: AnyObject>: EquivalenceDetector {
    func areEquivalent(lhs: Value, rhs: Value) -> Bool {
        return lhs === rhs
    }
}
