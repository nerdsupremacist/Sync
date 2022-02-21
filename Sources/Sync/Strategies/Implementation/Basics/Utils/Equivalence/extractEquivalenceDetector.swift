
import Foundation
@_implementationOnly import CSyncHelpers

func extractEquivalenceDetector<T>(for type: T.Type) -> AnyEquivalenceDetector<T>? {
    if let conformanceRecord = ProtocolConformanceRecord(implementationType: type, protocolType: equatableType) {
        let function = unsafeBitCast(makeEquatableEquivalenceDetectorFunction, to: MakeFunction<T>.self)
        let typePointer = unsafeBitCast(type as Any.Type, to: UnsafeRawPointer.self)
        return function(typePointer, conformanceRecord, conformanceRecord.witnessTable!).detector
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

public struct _AnyEquivalenceDetectorBox<T> {
    fileprivate let detector: AnyEquivalenceDetector<T>
}

private typealias MakeFunction<T> = @convention(thin) (UnsafeRawPointer, ProtocolConformanceRecord, UnsafeRawPointer) -> _AnyEquivalenceDetectorBox<T>

@_silgen_name("_swift_sync_makeEquatableEquivalenceDetector")
@available(*, unavailable)
public func makeEquatableEquivalenceDetector<T: Equatable>(type: T.Type) -> _AnyEquivalenceDetectorBox<T> {
    return _AnyEquivalenceDetectorBox(detector: AnyEquivalenceDetector(EquatableEquivalenceDetector()))
}

private let equatableType: Any.Type = {
    return _typeByName("SQ")!
}()

private let makeEquatableEquivalenceDetectorFunction: UnsafeMutableRawPointer = {
    return CSyncHelpers.makeEquatableEquivalenceDetector()
}()

private struct ProtocolConformanceRecord {
    let type: Any.Type
    let witnessTable: UnsafeRawPointer?
}

extension ProtocolConformanceRecord {

    init?(implementationType: Any.Type, protocolType: Any.Type) {
        let metadata = ProtocolMetadata(type: protocolType)
        guard let witnessTable = _conformsToProtocol(implementationType, metadata.protocolDescriptorVector) else { return nil }
        self.init(type: implementationType, witnessTable: witnessTable)
    }

}

private struct ProtocolDescriptor { }

private struct ProtocolMetadata {
    let kind: Int
    let layoutFlags: UInt32
    let numberOfProtocols: UInt32
    let protocolDescriptorVector: UnsafeMutablePointer<ProtocolDescriptor>

    init(type: Any.Type) {
        self = unsafeBitCast(type, to: UnsafeMutablePointer<Self>.self).pointee
    }
}

@_silgen_name("swift_conformsToProtocol")
private func _conformsToProtocol(
    _ type: Any.Type,
    _ protocolDescriptor: UnsafeMutablePointer<ProtocolDescriptor>
) -> UnsafeRawPointer?
