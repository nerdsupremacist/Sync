
import Foundation

struct AnyEquivalenceDetector<Value>: EquivalenceDetector {
    private class BaseStorage {
        func areEquivalent(lhs: Value, rhs: Value) -> Bool {
            fatalError()
        }
    }

    private final class Storage<Detector: EquivalenceDetector>: BaseStorage where Detector.Value == Value {
        let detector: Detector

        init(_ detector: Detector) {
            self.detector = detector
        }

        override func areEquivalent(lhs: Value, rhs: Value) -> Bool {
            return detector.areEquivalent(lhs: lhs, rhs: rhs)
        }
    }

    private let storage: BaseStorage

    init<Detector: EquivalenceDetector>(_ detector: Detector) where Detector.Value == Value {
        self.storage = Storage(detector)
    }

    func areEquivalent(lhs: Value, rhs: Value) -> Bool {
        return storage.areEquivalent(lhs: lhs, rhs: rhs)
    }
}
