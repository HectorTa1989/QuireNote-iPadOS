import Foundation
import Testing
@testable import QuireCore

@Suite("Atomic notebook store")
struct AtomicNotebookStoreTests {
    @Test("Saving creates the package and reloads the sidecar")
    func saveAndLoad() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("QuireCoreTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let packageURL = root.appendingPathComponent("Signals.quire", isDirectory: true)
        let paper = Paper(kind: .lined, size: .a4)
        let notebook = Notebook(
            title: "Signals",
            paper: paper,
            pages: [PageRef(background: .template(paper))]
        )
        let store = AtomicNotebookStore()

        try store.save(notebook, in: packageURL)
        let loaded = try store.load(from: packageURL)

        #expect(loaded == notebook)
        #expect(FileManager.default.fileExists(atPath: packageURL.appendingPathComponent("pages").path))
        #expect(FileManager.default.fileExists(atPath: packageURL.appendingPathComponent("notebook.json").path))
    }
}
