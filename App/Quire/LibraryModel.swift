import Combine
import Foundation
import QuireCore

enum LibrarySort: String, CaseIterable, Identifiable {
    case modified
    case title
    case pageCount

    var id: Self { self }
}

struct NotebookSummary: Identifiable, Hashable {
    let id: UUID
    var title: String
    var pageCount: Int
    var modifiedAt: Date
    var packageURL: URL
}

@MainActor
final class LibraryModel: ObservableObject {
    @Published private(set) var notebooks: [NotebookSummary] = []
    @Published private(set) var libraryURL: URL?
    @Published var searchText = ""
    @Published var sortOrder = LibrarySort.modified
    @Published var errorMessage: String?
    @Published var isLoading = false

    private let repository = NotebookRepository()

    var filteredNotebooks: [NotebookSummary] {
        let filtered = searchText.isEmpty
            ? notebooks
            : notebooks.filter { $0.title.localizedStandardContains(searchText) }
        switch sortOrder {
        case .modified:
            return filtered.sorted { $0.modifiedAt > $1.modifiedAt }
        case .title:
            return filtered.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        case .pageCount:
            return filtered.sorted { $0.pageCount > $1.pageCount }
        }
    }

    func restoreLibrary() async {
        isLoading = true
        defer { isLoading = false }
        do {
            if let restoredURL = try repository.restoreLibraryLocation() {
                libraryURL = restoredURL
                notebooks = try repository.listNotebooks(in: restoredURL)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func chooseLibrary(_ url: URL) async {
        isLoading = true
        defer { isLoading = false }
        do {
            try repository.setLibraryLocation(url)
            libraryURL = url
            notebooks = try repository.listNotebooks(in: url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createNotebook(title: String, paper: Paper) async -> URL? {
        guard let libraryURL else { return nil }
        do {
            let url = try repository.createNotebook(title: title, paper: paper, in: libraryURL)
            notebooks = try repository.listNotebooks(in: libraryURL)
            return url
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func importPDF(_ sourceURL: URL) async -> URL? {
        guard let libraryURL else { return nil }
        isLoading = true
        defer { isLoading = false }
        do {
            let url = try repository.importPDF(sourceURL, in: libraryURL)
            notebooks = try repository.listNotebooks(in: libraryURL)
            return url
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}
