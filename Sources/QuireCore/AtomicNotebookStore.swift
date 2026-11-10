import Foundation

public struct AtomicNotebookStore: Sendable {
    public init() {}

    public func save(_ notebook: Notebook, in packageURL: URL) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: packageURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(
            at: packageURL.appendingPathComponent(FileLayout.pagesDirectory, isDirectory: true),
            withIntermediateDirectories: true
        )

        let data = try NotebookCodec.encode(notebook)
        let destination = packageURL.appendingPathComponent(FileLayout.sidecarName)
        try CoordinatedFileIO.write(data, to: destination)
    }

    public func load(from packageURL: URL) throws -> Notebook {
        let sidecar = packageURL.appendingPathComponent(FileLayout.sidecarName)
        return try NotebookCodec.decode(CoordinatedFileIO.read(from: sidecar))
    }
}
