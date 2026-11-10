import Foundation

public enum PaperKind: String, Codable, CaseIterable, Sendable {
    case blank
    case lined
    case grid
    case dotted
    case cornell
}

public enum PaperSize: String, Codable, CaseIterable, Sendable {
    case a4
    case usLetter
}

public struct Paper: Codable, Equatable, Sendable {
    public var kind: PaperKind
    public var size: PaperSize

    public init(kind: PaperKind, size: PaperSize) {
        self.kind = kind
        self.size = size
    }
}
