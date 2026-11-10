import Foundation
import PDFKit
import PencilKit
import QuireCore
import QuireRender

enum NotebookRepositoryError: LocalizedError {
    case folderAccessDenied
    case invalidPDF

    var errorDescription: String? {
        switch self {
        case .folderAccessDenied:
            "Quire no longer has access to that folder. Choose it again."
        case .invalidPDF:
            "The selected PDF has no readable pages."
        }
    }
}

struct NotebookRepository {
    private static let bookmarkKey = "Quire.LibraryBookmark"
    private let store = AtomicNotebookStore()
    private let renderer = NotebookPDFRenderer()

    func setLibraryLocation(_ url: URL) throws {
        guard url.startAccessingSecurityScopedResource() else {
            throw NotebookRepositoryError.folderAccessDenied
        }
        defer { url.stopAccessingSecurityScopedResource() }
        let bookmark = try url.bookmarkData(options: .minimalBookmark)
        UserDefaults.standard.set(bookmark, forKey: Self.bookmarkKey)
    }

    func restoreLibraryLocation() throws -> URL? {
        guard let data = UserDefaults.standard.data(forKey: Self.bookmarkKey) else { return nil }
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: data,
            options: .withoutUI,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        if isStale { try setLibraryLocation(url) }
        return url
    }

    func listNotebooks(in libraryURL: URL) throws -> [NotebookSummary] {
        try withAccess(to: libraryURL) {
            let keys: Set<URLResourceKey> = [.contentModificationDateKey, .isDirectoryKey]
            let urls = try FileManager.default.contentsOfDirectory(
                at: libraryURL,
                includingPropertiesForKeys: Array(keys),
                options: [.skipsHiddenFiles]
            )

            return try urls.compactMap { url in
                guard url.pathExtension.lowercased() == "quire" else { return nil }
                let notebook = try store.load(from: url)
                let values = try url.resourceValues(forKeys: keys)
                return NotebookSummary(
                    id: notebook.id,
                    title: notebook.title,
                    pageCount: notebook.pages.count,
                    modifiedAt: values.contentModificationDate ?? notebook.createdAt,
                    packageURL: url
                )
            }
            .sorted { $0.modifiedAt > $1.modifiedAt }
        }
    }

    func createNotebook(title: String, paper: Paper, in libraryURL: URL) throws -> URL {
        try withAccess(to: libraryURL) {
            let page = PageRef(background: .template(paper))
            let notebook = Notebook(title: title, paper: paper, pages: [page])
            let packageURL = uniquePackageURL(title: title, in: libraryURL)
            try store.save(notebook, in: packageURL)
            let drawing = PKDrawing()
            try CoordinatedFileIO.write(
                drawing.dataRepresentation(),
                to: packageURL.appendingPathComponent(page.strokesFile)
            )
            try renderer.render(
                notebook: notebook,
                drawings: [page.id: drawing],
                packageURL: packageURL
            )
            return packageURL
        }
    }

    func importPDF(_ sourceURL: URL, in libraryURL: URL) throws -> URL {
        let hasSourceAccess = sourceURL.startAccessingSecurityScopedResource()
        defer { if hasSourceAccess { sourceURL.stopAccessingSecurityScopedResource() } }

        guard let source = PDFDocument(url: sourceURL), source.pageCount > 0 else {
            throw NotebookRepositoryError.invalidPDF
        }

        return try withAccess(to: libraryURL) {
            let title = sourceURL.deletingPathExtension().lastPathComponent
            let paper = Paper(kind: .blank, size: .a4)
            let packageURL = uniquePackageURL(title: title, in: libraryURL)
            try FileManager.default.createDirectory(
                at: packageURL.appendingPathComponent(FileLayout.pagesDirectory, isDirectory: true),
                withIntermediateDirectories: true
            )

            var pages: [PageRef] = []
            for index in 0..<source.pageCount {
                guard let originalPage = source.page(at: index),
                      let copiedPage = originalPage.copy() as? PDFPage else { continue }
                let pageID = UUID()
                let backgroundPath = FileLayout.backgroundPDFPath(for: pageID)
                let singlePageDocument = PDFDocument()
                singlePageDocument.insert(copiedPage, at: 0)
                guard let backgroundData = singlePageDocument.dataRepresentation() else { continue }
                try CoordinatedFileIO.write(
                    backgroundData,
                    to: packageURL.appendingPathComponent(backgroundPath)
                )

                let page = PageRef(
                    id: pageID,
                    background: .pdf(file: backgroundPath, pageIndex: 0)
                )
                try CoordinatedFileIO.write(
                    PKDrawing().dataRepresentation(),
                    to: packageURL.appendingPathComponent(page.strokesFile)
                )
                pages.append(page)
            }

            guard !pages.isEmpty else { throw NotebookRepositoryError.invalidPDF }
            let notebook = Notebook(title: title, paper: paper, pages: pages)
            try store.save(notebook, in: packageURL)

            let portablePDF = packageURL.appendingPathComponent(
                FileLayout.flattenedPDFName(notebookTitle: title)
            )
            try CoordinatedFileIO.write(Data(contentsOf: sourceURL), to: portablePDF)
            return packageURL
        }
    }

    private func withAccess<T>(to url: URL, perform body: () throws -> T) throws -> T {
        guard url.startAccessingSecurityScopedResource() else {
            throw NotebookRepositoryError.folderAccessDenied
        }
        defer { url.stopAccessingSecurityScopedResource() }
        return try body()
    }

    private func uniquePackageURL(title: String, in libraryURL: URL) -> URL {
        let base = URL(fileURLWithPath: FileLayout.packageName(notebookTitle: title)).deletingPathExtension().lastPathComponent
        var suffix = 1
        var candidate = libraryURL.appendingPathComponent("\(base).quire", isDirectory: true)
        while FileManager.default.fileExists(atPath: candidate.path) {
            suffix += 1
            candidate = libraryURL.appendingPathComponent("\(base) \(suffix).quire", isDirectory: true)
        }
        return candidate
    }
}
