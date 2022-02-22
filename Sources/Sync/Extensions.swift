
import Foundation
import OpenCombineShim

extension Sequence where Element: Publisher {

    func mergeMany() -> AnyPublisher<Element.Output, Element.Failure> {
        #if canImport(Combine)
        return Publishers.MergeMany(self).eraseToAnyPublisher()
        #else
        return MergeMany(publishers: Array(self)).eraseToAnyPublisher()
        #endif
    }

}

#if !canImport(Combine)
extension Publisher {

    func merge<P>(with other: P) -> Merge<Self, P> where P : Publisher, Self.Failure == P.Failure, Self.Output == P.Output {
        return Merge(a: self, b: other)
    }

}

struct Merge<A: Publisher, B: Publisher>: Publisher where A.Output == B.Output, A.Failure == B.Failure {
    typealias Output = A.Output
    typealias Failure = B.Failure

    let a: A
    let b: B

    func merge<C>(with c: C) -> Merge3<A, B, C> where C : Publisher, Self.Failure == C.Failure, Self.Output == C.Output {
        return Merge3(a: a, b: b, c: c)
    }

    func receive<S>(subscriber: S) where S : Subscriber, B.Failure == S.Failure, A.Output == S.Input {
        a.receive(subscriber: subscriber)
        b.receive(subscriber: subscriber)
    }
}

struct Merge3<A: Publisher, B: Publisher, C: Publisher>: Publisher where A.Output == B.Output, A.Output == C.Output, A.Failure == B.Failure, A.Failure == C.Failure {
    typealias Output = A.Output
    typealias Failure = B.Failure

    let a: A
    let b: B
    let c: C

    func receive<S>(subscriber: S) where S : Subscriber, B.Failure == S.Failure, A.Output == S.Input {
        a.receive(subscriber: subscriber)
        b.receive(subscriber: subscriber)
        c.receive(subscriber: subscriber)
    }
}

private struct MergeMany<T : Publisher>: Publisher {
    typealias Output = T.Output
    typealias Failure = T.Failure

    let publishers: [T]

    func receive<S>(subscriber: S) where S : Subscriber, T.Failure == S.Failure, T.Output == S.Input {
        for publisher in publishers {
            publisher.receive(subscriber: subscriber)
        }
    }
}
#endif
