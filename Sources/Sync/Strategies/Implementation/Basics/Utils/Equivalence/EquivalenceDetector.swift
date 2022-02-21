
import Foundation

protocol EquivalenceDetector {
    associatedtype Value

    func areEquivalent(lhs: Value, rhs: Value) -> Bool
}
