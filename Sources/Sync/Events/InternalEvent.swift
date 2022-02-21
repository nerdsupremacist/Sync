
import Foundation

enum InternalEvent {
    case delete([PathComponent])
    case write([PathComponent], Data)
    case insert([PathComponent], index: Int, Data)

    func oneLevelLower() -> InternalEvent {
        switch self {
        case .write(let path, let data):
            return .write(Array(path.dropFirst()), data)
        case .delete(let path):
            return .delete(Array(path.dropFirst()))
        case .insert(let path, let index, let data):
            return .insert(Array(path.dropFirst()), index: index, data)
        }
    }

    func prefix(by index: Int) -> InternalEvent {
        switch self {
        case .write(let path, let data):
            return .write([.index(index)] + path, data)
        case .delete(let path):
            return .delete([.index(index)] + path)
        case .insert(let path, let insertionIndex, let data):
            return .insert([.index(index)] + path, index: insertionIndex, data)
        }
    }

    func prefix(by label: String) -> InternalEvent {
        switch self {
        case .write(let path, let data):
            return .write([.name(label)] + path, data)
        case .delete(let path):
            return .delete([.name(label)] + path)
        case .insert(let path, let insertionIndex, let data):
            return .insert([.name(label)] + path, index: insertionIndex, data)
        }
    }
}

extension PathComponent: Codable {
    private enum Kind: Int, Codable {
        case label
        case index
    }

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        switch try container.decode(Kind.self) {
        case .label:
            self = .name(try container.decode(String.self))
        case .index:
            self = .index(try container.decode(Int.self))
        }
        assert(container.isAtEnd)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        switch self {
        case .name(let name):
            try container.encode(Kind.label)
            try container.encode(name)
        case .index(let index):
            try container.encode(Kind.index)
            try container.encode(index)
        }
    }
}

extension InternalEvent: Codable {
    private enum Kind: Int, Codable {
        case write
        case delete
        case insert
    }

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        switch try container.decode(Kind.self) {
        case .write:
            self = .write(try container.decode([PathComponent].self), try container.decode(Data.self))
        case .delete:
            self = .delete(try container.decode([PathComponent].self))
        case .insert:
            self = .insert(try container.decode([PathComponent].self), index: try container.decode(Int.self), try container.decode(Data.self))
        }
        assert(container.isAtEnd)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        switch self {
        case .write(let path, let data):
            try container.encode(Kind.write)
            try container.encode(path)
            try container.encode(data)
        case .delete(let path):
            try container.encode(Kind.delete)
            try container.encode(path)
        case .insert(let path, let index, let data):
            try container.encode(Kind.insert)
            try container.encode(path)
            try container.encode(index)
            try container.encode(data)
        }
    }
}
