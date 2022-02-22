
import Foundation
#if canImport(AssociatedTypeRequirementsVisitor)
@_implementationOnly import AssociatedTypeRequirementsVisitor
#endif

func extractEquivalenceDetector<T>(for type: T.Type) -> AnyEquivalenceDetector<T>? {
    #if canImport(AssociatedTypeRequirementsVisitor)
    if let equatableDetector = EquivalenceDetectorForEquatableFatory.detector(for: type) {
        return equatableDetector.read()
    }
    #endif
    if let type = type as? HasErasedErasedEquivalenceDetector.Type {
        return type.erasedEquivalenceDetector?.read()
    }
    if let type = type as? SyncableObject.Type {
        return type.erasedEquivalenceDetector.read()
    }
    return nil
}

extension SyncableObject {
    static var erasedEquivalenceDetector: ErasedEquivalenceDetector {
        return ErasedEquivalenceDetector(ReferenceEquivalenceDetector<Self>())
    }
}

#if canImport(AssociatedTypeRequirementsVisitor)
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
#endif
