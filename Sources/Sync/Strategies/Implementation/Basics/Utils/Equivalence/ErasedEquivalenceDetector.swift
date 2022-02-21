
import Foundation

protocol HasErasedErasedEquivalenceDetector {
    static var erasedEquivalenceDetector: ErasedEquivalenceDetector? { get }
}

class ErasedEquivalenceDetector {
    private let detector: Any

    init<T: EquivalenceDetector>(_ detector: T) {
        self.detector = AnyEquivalenceDetector(detector)
    }

    func read<Value>() -> AnyEquivalenceDetector<Value> {
        guard let detector = detector as? AnyEquivalenceDetector<Value> else { fatalError() }
        return detector
    }
}
