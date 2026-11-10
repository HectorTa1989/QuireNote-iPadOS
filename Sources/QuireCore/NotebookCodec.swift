import Foundation

public enum NotebookFormatError: Error, Equatable, LocalizedError {
    case invalidTopLevelObject
    case missingSchemaVersion
    case unsupportedSchemaVersion(Int)
    case invalidRelativePath(String)
    case duplicatePageID(UUID)

    public var errorDescription: String? {
        switch self {
        case .invalidTopLevelObject:
            "notebook.json must contain a JSON object"
        case .missingSchemaVersion:
            "notebook.json is missing schemaVersion"
        case let .unsupportedSchemaVersion(version):
            "Notebook schema version \(version) is not supported"
        case let .invalidRelativePath(path):
            "Notebook contains an unsafe package-relative path: \(path)"
        case let .duplicatePageID(id):
            "Notebook contains duplicate page ID \(id.uuidString)"
        }
    }
}

public enum NotebookCodec {
    public static func encode(_ notebook: Notebook) throws -> Data {
        try validate(notebook)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(notebook)
    }

    public static func decode(_ data: Data) throws -> Notebook {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NotebookFormatError.invalidTopLevelObject
        }
        guard let version = object["schemaVersion"] as? Int else {
            throw NotebookFormatError.missingSchemaVersion
        }
        guard version == Notebook.currentSchemaVersion else {
            throw NotebookFormatError.unsupportedSchemaVersion(version)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let notebook = try decoder.decode(Notebook.self, from: data)
        try validate(notebook)
        return notebook
    }

    public static func validate(_ notebook: Notebook) throws {
        guard notebook.schemaVersion == Notebook.currentSchemaVersion else {
            throw NotebookFormatError.unsupportedSchemaVersion(notebook.schemaVersion)
        }

        var pageIDs = Set<UUID>()
        for page in notebook.pages {
            guard pageIDs.insert(page.id).inserted else {
                throw NotebookFormatError.duplicatePageID(page.id)
            }
            guard FileLayout.isSafeRelativePath(page.strokesFile) else {
                throw NotebookFormatError.invalidRelativePath(page.strokesFile)
            }
            if case let .pdf(file, _) = page.background,
               !FileLayout.isSafeRelativePath(file) {
                throw NotebookFormatError.invalidRelativePath(file)
            }
        }
    }
}
