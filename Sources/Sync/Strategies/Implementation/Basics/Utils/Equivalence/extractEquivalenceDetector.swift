
import Foundation
@_implementationOnly import AssociatedTypeRequirementsVisitor

func extractEquivalenceDetector<T>(for type: T.Type) -> AnyEquivalenceDetector<T>? {
    if let equatableDetector = EquivalenceDetectorForEquatableFatory.detector(for: type) {
        return equatableDetector.read()
    }
    if let type = type as? HasErasedErasedEquivalenceDetector.Type {
        return type.erasedEquivalenceDetector?.read()
    }
    if let type = type as? SyncedObject.Type {
        return type.erasedEquivalenceDetector.read()
    }
    return nil
}

extension SyncedObject {
    static var erasedEquivalenceDetector: ErasedEquivalenceDetector {
        return ErasedEquivalenceDetector(ReferenceEquivalenceDetector<Self>())
    }
}

private struct EquivalenceDetectorForEquatableFatory: EquatableTypeVisitor {
    typealias Output = ErasedEquivalenceDetector

    private static let shared = EquivalenceDetectorForEquatableFatory()

    private init() {}

    func callAsFunction<T>(_ type: T.Type) -> ErasedEquivalenceDetector where T : Equatable {
        return ErasedEquivalenceDetector(EquatableEquivalenceDetector<T>())
    }

    public static func detector(for type: Any.Type) -> ErasedEquivalenceDetector? {
        return shared(type)
    }
}
