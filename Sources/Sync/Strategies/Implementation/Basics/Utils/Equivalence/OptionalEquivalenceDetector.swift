
import Foundation

struct OptionalEquivalenceDetector<Wrapped>: EquivalenceDetector {
    typealias Value = Wrapped?

    let detector: AnyEquivalenceDetector<Wrapped>

    func areEquivalent(lhs: Wrapped?, rhs: Wrapped?) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none):
            return true
        case (.some(let lhs), .some(let rhs)):
            return detector.areEquivalent(lhs: lhs, rhs: rhs)
        default:
            return false
        }
    }
}

extension Optional: HasErasedErasedEquivalenceDetector {
    static var erasedEquivalenceDetector: ErasedEquivalenceDetector? {
        guard let detector = extractEquivalenceDetector(for: Wrapped.self) else { return nil }
        return ErasedEquivalenceDetector(OptionalEquivalenceDetector(detector: detector))
    }
}
