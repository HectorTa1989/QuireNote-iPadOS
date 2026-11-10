import Foundation

public enum FileLayout {
    public static let sidecarName = "notebook.json"
    public static let pagesDirectory = "pages"

    public static func drawingPath(for pageID: UUID) -> String {
        "\(pagesDirectory)/\(pageID.uuidString.lowercased()).drawing"
    }

    public static func backgroundPDFPath(for pageID: UUID) -> String {
        "\(pagesDirectory)/\(pageID.uuidString.lowercased()).bg.pdf"
    }

    public static func flattenedPDFName(notebookTitle: String) -> String {
        "\(safeFileStem(notebookTitle)).pdf"
    }

    public static func packageName(notebookTitle: String) -> String {
        "\(safeFileStem(notebookTitle)).quire"
    }

    public static func isSafeRelativePath(_ path: String) -> Bool {
        guard !path.isEmpty, !path.hasPrefix("/"), !path.hasPrefix("\\") else { return false }
        guard !path.contains("\\"), !path.contains(":") else { return false }
        return !path.split(separator: "/", omittingEmptySubsequences: false).contains("..")
    }

    private static func safeFileStem(_ value: String) -> String {
        let invalid = CharacterSet(charactersIn: "<>:\"/\\|?*").union(.controlCharacters)
        let cleaned = value.unicodeScalars.map { invalid.contains($0) ? "_" : String($0) }.joined()
        let trimmed = cleaned.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ".")))
        return trimmed.isEmpty ? "Untitled" : String(trimmed.prefix(120))
    }
}
