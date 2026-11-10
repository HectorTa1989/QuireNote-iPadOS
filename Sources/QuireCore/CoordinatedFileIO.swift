import Foundation

public enum CoordinatedFileIO {
    public static func write(_ data: Data, to url: URL) throws {
        #if os(iOS) || os(macOS)
        var coordinationError: NSError?
        var operationError: (any Error)?
        NSFileCoordinator().coordinate(
            writingItemAt: url,
            options: [],
            error: &coordinationError
        ) { coordinatedURL in
            do {
                try data.write(to: coordinatedURL, options: .atomic)
            } catch {
                operationError = error
            }
        }
        if let operationError { throw operationError }
        if let coordinationError { throw coordinationError }
        #else
        try data.write(to: url, options: .atomic)
        #endif
    }

    public static func read(from url: URL) throws -> Data {
        #if os(iOS) || os(macOS)
        var coordinationError: NSError?
        var result: Result<Data, any Error>?
        NSFileCoordinator().coordinate(
            readingItemAt: url,
            options: [],
            error: &coordinationError
        ) { coordinatedURL in
            result = Result { try Data(contentsOf: coordinatedURL) }
        }
        if let coordinationError { throw coordinationError }
        guard let result else { throw CocoaError(.fileReadUnknown) }
        return try result.get()
        #else
        return try Data(contentsOf: url)
        #endif
    }
}
