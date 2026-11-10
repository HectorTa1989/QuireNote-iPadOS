import Foundation

public enum Background: Equatable, Sendable {
    case template(Paper)
    case pdf(file: String, pageIndex: Int)
}

extension Background: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case paper
        case file
        case pageIndex
    }

    private enum Kind: String, Codable {
        case template
        case pdf
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .type) {
        case .template:
            self = .template(try container.decode(Paper.self, forKey: .paper))
        case .pdf:
            let file = try container.decode(String.self, forKey: .file)
            let pageIndex = try container.decode(Int.self, forKey: .pageIndex)
            guard pageIndex >= 0 else {
                throw DecodingError.dataCorruptedError(
                    forKey: .pageIndex,
                    in: container,
                    debugDescription: "PDF pageIndex cannot be negative"
                )
            }
            self = .pdf(file: file, pageIndex: pageIndex)
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .template(paper):
            try container.encode(Kind.template, forKey: .type)
            try container.encode(paper, forKey: .paper)
        case let .pdf(file, pageIndex):
            try container.encode(Kind.pdf, forKey: .type)
            try container.encode(file, forKey: .file)
            try container.encode(pageIndex, forKey: .pageIndex)
        }
    }
}

public struct PageRef: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var background: Background
    public var strokesFile: String
    public var recognizedText: String?
    public var recognizedAt: Date?
    public var recognitionTokens: [RecognitionToken]?

    public init(
        id: UUID = UUID(),
        background: Background,
        strokesFile: String? = nil,
        recognizedText: String? = nil,
        recognizedAt: Date? = nil,
        recognitionTokens: [RecognitionToken]? = nil
    ) {
        self.id = id
        self.background = background
        self.strokesFile = strokesFile ?? FileLayout.drawingPath(for: id)
        self.recognizedText = recognizedText
        self.recognizedAt = recognizedAt
        self.recognitionTokens = recognitionTokens
    }
}

public struct Notebook: Codable, Equatable, Identifiable, Sendable {
    public static let currentSchemaVersion = 1

    public var id: UUID
    public var title: String
    public var paper: Paper
    public var pages: [PageRef]
    public var createdAt: Date
    public var schemaVersion: Int

    public init(
        id: UUID = UUID(),
        title: String,
        paper: Paper,
        pages: [PageRef] = [],
        createdAt: Date = Date(),
        schemaVersion: Int = currentSchemaVersion
    ) {
        self.id = id
        self.title = title
        self.paper = paper
        self.pages = pages
        self.createdAt = createdAt
        self.schemaVersion = schemaVersion
    }
}
