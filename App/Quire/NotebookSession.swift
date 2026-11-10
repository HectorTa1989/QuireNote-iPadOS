import Combine
import Foundation
import PDFKit
import PencilKit
import QuireCore
import QuireRender

@MainActor
final class NotebookSession: ObservableObject {
    @Published private(set) var notebook: Notebook?
    @Published var drawing = PKDrawing()
    @Published private(set) var currentPageIndex = 0
    @Published private(set) var loadError: String?
    @Published private(set) var isSaving = false
    @Published private(set) var canUndo = false
    @Published var searchText = ""
    @Published private(set) var searchResults: [NotebookSearchResult] = []
    @Published private(set) var highlightBounds: [QuireRect] = []

    let packageURL: URL

    private let store = AtomicNotebookStore()
    private let renderer = NotebookPDFRenderer()
    private let recognitionService = HandwritingRecognitionService()
    private var drawings: [UUID: PKDrawing] = [:]
    private var dirtyPageIDs = Set<UUID>()
    private var autosaveTask: Task<Void, Never>?
    private weak var canvasView: PKCanvasView?

    init(packageURL: URL) {
        self.packageURL = packageURL
    }

    var pageCount: Int { notebook?.pages.count ?? 0 }

    var currentPaper: Paper? {
        guard let notebook, notebook.pages.indices.contains(currentPageIndex) else { return nil }
        switch notebook.pages[currentPageIndex].background {
        case let .template(paper): paper
        case .pdf: notebook.paper
        }
    }

    var currentBackground: Background? { currentPage?.background }

    var currentBackgroundURL: URL? {
        guard case let .pdf(file, _) = currentPage?.background else { return nil }
        return packageURL.appendingPathComponent(file)
    }

    var flattenedPDFURL: URL? {
        guard let notebook else { return nil }
        let url = packageURL.appendingPathComponent(FileLayout.flattenedPDFName(notebookTitle: notebook.title))
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    var currentPageSize: QuireSize {
        if case let .pdf(file, pageIndex) = currentPage?.background,
           let page = PDFDocument(url: packageURL.appendingPathComponent(file))?.page(at: pageIndex) {
            let bounds = page.bounds(for: .mediaBox)
            return QuireSize(width: bounds.width, height: bounds.height)
        }
        return TemplateGeometry.pageSize(for: currentPaper ?? Paper(kind: .blank, size: .a4))
    }

    var pageAspectRatio: CGFloat {
        if case let .pdf(file, pageIndex) = currentPage?.background,
           let page = PDFDocument(url: packageURL.appendingPathComponent(file))?.page(at: pageIndex) {
            let bounds = page.bounds(for: .mediaBox)
            return bounds.width / bounds.height
        }
        guard let currentPaper else { return 210 / 297 }
        let size = TemplateGeometry.pageSize(for: currentPaper)
        return size.width / size.height
    }

    func load() async {
        guard notebook == nil else { return }
        do {
            notebook = try withPackageAccess { try store.load(from: packageURL) }
            try loadDrawing(at: 0)
        } catch {
            loadError = error.localizedDescription
        }
    }

    func attachCanvas(_ canvas: PKCanvasView) {
        canvasView = canvas
        canUndo = canvas.undoManager?.canUndo ?? false
    }

    func drawingDidChange(_ newDrawing: PKDrawing) {
        drawing = newDrawing
        if let pageID = currentPage?.id { drawings[pageID] = newDrawing }
        if let pageID = currentPage?.id { dirtyPageIDs.insert(pageID) }
        canUndo = canvasView?.undoManager?.canUndo ?? false
        scheduleAutosave()
    }

    func undo() {
        canvasView?.undoManager?.undo()
        canUndo = canvasView?.undoManager?.canUndo ?? false
    }

    func selectPage(_ index: Int) async {
        guard index != currentPageIndex,
              let notebook,
              notebook.pages.indices.contains(index) else { return }
        await saveNow()
        currentPageIndex = index
        highlightBounds = []
        do { try loadDrawing(at: index) } catch { loadError = error.localizedDescription }
    }

    func addPage() {
        guard var notebook else { return }
        drawings[notebook.pages[currentPageIndex].id] = drawing
        let page = PageRef(background: .template(notebook.paper))
        notebook.pages.append(page)
        self.notebook = notebook
        currentPageIndex = notebook.pages.count - 1
        drawing = PKDrawing()
        drawings[page.id] = drawing
        scheduleAutosave()
    }

    func deleteCurrentPage() {
        guard var notebook, notebook.pages.count > 1 else { return }
        let removed = notebook.pages.remove(at: currentPageIndex)
        drawings.removeValue(forKey: removed.id)
        try? withPackageAccess {
            try? FileManager.default.removeItem(at: packageURL.appendingPathComponent(removed.strokesFile))
            if case let .pdf(file, _) = removed.background {
                try? FileManager.default.removeItem(at: packageURL.appendingPathComponent(file))
            }
        }
        currentPageIndex = min(currentPageIndex, notebook.pages.count - 1)
        self.notebook = notebook
        do { try loadDrawing(at: currentPageIndex) } catch { loadError = error.localizedDescription }
        scheduleAutosave()
    }

    func moveCurrentPage(by offset: Int) {
        guard var notebook else { return }
        let destination = currentPageIndex + offset
        guard notebook.pages.indices.contains(destination) else { return }
        let page = notebook.pages.remove(at: currentPageIndex)
        notebook.pages.insert(page, at: destination)
        currentPageIndex = destination
        self.notebook = notebook
        scheduleAutosave()
    }

    func saveNow() async {
        autosaveTask?.cancel()
        guard !isSaving, let notebook else { return }
        isSaving = true
        defer { isSaving = false }
        if let pageID = currentPage?.id { drawings[pageID] = drawing }

        var updatedNotebook = notebook
        let pagesToRecognize = dirtyPageIDs
        dirtyPageIDs.subtract(pagesToRecognize)

        for pageID in pagesToRecognize {
            guard let pageIndex = updatedNotebook.pages.firstIndex(where: { $0.id == pageID }),
                  let pageDrawing = drawings[pageID],
                  let image = recognitionImage(for: pageDrawing, page: updatedNotebook.pages[pageIndex]) else { continue }
            do {
                let pageSize = size(for: updatedNotebook.pages[pageIndex])
                let output = try await recognitionService.recognize(image: image, pageSize: pageSize)
                updatedNotebook.pages[pageIndex].recognizedText = output.text
                updatedNotebook.pages[pageIndex].recognizedAt = Date()
                updatedNotebook.pages[pageIndex].recognitionTokens = output.tokens
            } catch {
                dirtyPageIDs.insert(pageID)
            }
        }
        self.notebook = updatedNotebook

        do {
            try withPackageAccess {
                for page in updatedNotebook.pages {
                    guard let pageDrawing = drawings[page.id] else { continue }
                    try CoordinatedFileIO.write(
                        pageDrawing.dataRepresentation(),
                        to: packageURL.appendingPathComponent(page.strokesFile)
                    )
                }
                try store.save(updatedNotebook, in: packageURL)
                try renderer.render(notebook: updatedNotebook, drawings: drawings, packageURL: packageURL)
            }
        } catch {
            loadError = error.localizedDescription
        }
    }

    func runSearch() {
        guard let notebook else {
            searchResults = []
            return
        }
        var index = SearchIndex()
        for page in notebook.pages {
            index.update(
                pageID: page.id,
                text: page.recognizedText ?? "",
                tokens: page.recognitionTokens ?? []
            )
        }
        let hits = index.search(searchText, pageOrder: notebook.pages.map(\.id))
        searchResults = hits.compactMap { hit in
            guard let pageIndex = notebook.pages.firstIndex(where: { $0.id == hit.pageID }) else { return nil }
            return NotebookSearchResult(
                pageID: hit.pageID,
                pageIndex: pageIndex,
                matchedText: hit.text,
                bounds: hit.strokeBounds
            )
        }
    }

    func openSearchResult(_ result: NotebookSearchResult) async {
        await selectPage(result.pageIndex)
        highlightBounds = result.bounds
    }

    private var currentPage: PageRef? {
        guard let notebook, notebook.pages.indices.contains(currentPageIndex) else { return nil }
        return notebook.pages[currentPageIndex]
    }

    private func loadDrawing(at index: Int) throws {
        guard let notebook, notebook.pages.indices.contains(index) else { return }
        let page = notebook.pages[index]
        if let cached = drawings[page.id] {
            drawing = cached
            return
        }
        let loaded = try withPackageAccess { () -> PKDrawing in
            let url = packageURL.appendingPathComponent(page.strokesFile)
            guard FileManager.default.fileExists(atPath: url.path) else { return PKDrawing() }
            let data = try CoordinatedFileIO.read(from: url)
            return data.isEmpty ? PKDrawing() : try PKDrawing(data: data)
        }
        drawings[page.id] = loaded
        drawing = loaded
    }

    private func scheduleAutosave() {
        autosaveTask?.cancel()
        autosaveTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            await self?.saveNow()
        }
    }

    private func recognitionImage(for drawing: PKDrawing, page: PageRef) -> CGImage? {
        let pageSize = size(for: page)
        let bounds = CGRect(x: 0, y: 0, width: pageSize.width, height: pageSize.height)
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(bounds)
            drawing.image(from: bounds, scale: 2).draw(in: bounds)
        }.cgImage
    }

    private func size(for page: PageRef) -> QuireSize {
        switch page.background {
        case let .template(paper):
            return TemplateGeometry.pageSize(for: paper)
        case let .pdf(file, pageIndex):
            if let pdfPage = PDFDocument(url: packageURL.appendingPathComponent(file))?.page(at: pageIndex) {
                let bounds = pdfPage.bounds(for: .mediaBox)
                return QuireSize(width: bounds.width, height: bounds.height)
            }
            return TemplateGeometry.pageSize(for: notebook?.paper ?? Paper(kind: .blank, size: .a4))
        }
    }

    private func withPackageAccess<T>(_ body: () throws -> T) throws -> T {
        let hasAccess = packageURL.startAccessingSecurityScopedResource()
        defer { if hasAccess { packageURL.stopAccessingSecurityScopedResource() } }
        return try body()
    }
}

struct NotebookSearchResult: Identifiable, Sendable {
    let pageID: UUID
    let pageIndex: Int
    let matchedText: String
    let bounds: [QuireRect]

    var id: String { "\(pageID.uuidString)-\(pageIndex)-\(matchedText)" }
}
