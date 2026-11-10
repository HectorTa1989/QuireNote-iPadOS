import Foundation
import Testing
@testable import QuireCore

@Suite("Package file layout")
struct FileLayoutTests {
    @Test("File names are safe on Windows and Apple platforms")
    func safeFileNames() {
        #expect(FileLayout.packageName(notebookTitle: "Civil: Procedure/2026") == "Civil_ Procedure_2026.quire")
        #expect(FileLayout.flattenedPDFName(notebookTitle: "  ... ") == "Untitled.pdf")
    }

    @Test("Only normalized package-relative paths are accepted", arguments: [
        ("pages/a.drawing", true),
        ("pages/../secret", false),
        ("../secret", false),
        ("/absolute", false),
        ("C:/absolute", false),
        ("pages\\a.drawing", false),
        ("", false),
    ])
    func relativePathValidation(path: String, expected: Bool) {
        #expect(FileLayout.isSafeRelativePath(path) == expected)
    }
}
