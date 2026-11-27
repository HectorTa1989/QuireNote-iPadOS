import PencilKit
import QuireCore
import SwiftUI

struct NotebookView: View {
    let packageURL: URL

    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var session: NotebookSession
    @State private var isSearching = false

    init(packageURL: URL) {
        self.packageURL = packageURL
        _session = StateObject(wrappedValue: NotebookSession(packageURL: packageURL))
    }

    var body: some View {
        Group {
            if let error = session.loadError {
                ContentUnavailableView(
                    "Couldn’t open this notebook",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            } else if session.notebook == nil {
                ProgressView("Opening notebook…")
            } else {
                editor
            }
        }
        .navigationTitle(session.notebook?.title ?? packageURL.deletingPathExtension().lastPathComponent)
        .navigationBarTitleDisplayMode(.inline)
        .task { await session.load() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                Task { await session.saveNow() }
            }
        }
    }

    private var editor: some View {
        VStack(spacing: 0) {
            pageStrip

            ZStack {
                Color(uiColor: .secondarySystemBackground)
                if session.currentBackground != nil {
                    PageBackgroundView(session: session)
                        .overlay {
                            PencilCanvasView(drawing: $session.drawing, session: session) { drawing in
                                session.drawingDidChange(drawing)
                            }
                        }
                        .overlay {
                            SearchHighlightOverlay(
                                bounds: session.highlightBounds,
                                pageSize: session.currentPageSize
                            )
                            .allowsHitTesting(false)
                        }
                        .aspectRatio(session.pageAspectRatio, contentMode: .fit)
                        .padding(24)
                        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
                }
            }

        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if let pdfURL = session.flattenedPDFURL {
                    ShareLink(item: pdfURL) {
                        Label("Export PDF", systemImage: "square.and.arrow.up")
                    }
                }

                Button {
                    isSearching = true
                } label: {
                    Label("Search Handwriting", systemImage: "text.magnifyingglass")
                }

                Button { session.undo() } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                }
                .disabled(!session.canUndo)

                Menu {
                    Button { session.addPage() } label: {
                        Label("Add Page", systemImage: "doc.badge.plus")
                    }
                    Button { session.moveCurrentPage(by: -1) } label: {
                        Label("Move Page Left", systemImage: "arrow.left")
                    }
                    .disabled(session.currentPageIndex == 0)
                    Button { session.moveCurrentPage(by: 1) } label: {
                        Label("Move Page Right", systemImage: "arrow.right")
                    }
                    .disabled(session.currentPageIndex == session.pageCount - 1)
                    Button(role: .destructive) { session.deleteCurrentPage() } label: {
                        Label("Delete Page", systemImage: "trash")
                    }
                    .disabled(session.pageCount <= 1)
                } label: {
                    Label("Page Actions", systemImage: "ellipsis.circle")
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if session.isSaving {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Saving")
                }
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.thinMaterial, in: Capsule())
                .padding(.top, 6)
            }
        }
        .sheet(isPresented: $isSearching) {
            HandwritingSearchView(session: session, isPresented: $isSearching)
        }
    }

    private var pageStrip: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(0..<session.pageCount, id: \.self) { index in
                        Button {
                            Task { await session.selectPage(index) }
                        } label: {
                            Text("\(index + 1)")
                                .font(.subheadline.monospacedDigit())
                                .frame(minWidth: 36, minHeight: 36)
                                .background(
                                    index == session.currentPageIndex ? Color.accentColor : Color.secondary.opacity(0.14),
                                    in: RoundedRectangle(cornerRadius: 8)
                                )
                                .foregroundStyle(index == session.currentPageIndex ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Page \(index + 1)")
                    }
                }
                .padding(.horizontal, 12)
            }

            Button { session.addPage() } label: {
                Image(systemName: "plus")
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Add Page")
            .padding(.trailing, 12)
        }
        .frame(height: 58)
        .background(.bar)
    }
}

private struct HandwritingSearchView: View {
    @ObservedObject var session: NotebookSession
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            Group {
                if session.searchText.isEmpty {
                    ContentUnavailableView(
                        "Search your handwriting",
                        systemImage: "text.magnifyingglass",
                        description: Text("Recognition runs on this device and stays inside the notebook.")
                    )
                } else if session.searchResults.isEmpty {
                    ContentUnavailableView.search(text: session.searchText)
                } else {
                    List(session.searchResults) { result in
                        Button {
                            Task {
                                await session.openSearchResult(result)
                                isPresented = false
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(result.matchedText)
                                    .foregroundStyle(.primary)
                                Text("Page \(result.pageIndex + 1)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Search")
            .searchable(text: $session.searchText, prompt: "Find handwritten text")
            .onSubmit(of: .search) { session.runSearch() }
            .onChange(of: session.searchText) { _, _ in session.runSearch() }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { isPresented = false }
                }
            }
        }
    }
}

private struct SearchHighlightOverlay: View {
    let bounds: [QuireRect]
    let pageSize: QuireSize

    var body: some View {
        Canvas { context, size in
            let scaleX = size.width / pageSize.width
            let scaleY = size.height / pageSize.height
            for bound in bounds {
                let rect = CGRect(
                    x: bound.origin.x * scaleX,
                    y: bound.origin.y * scaleY,
                    width: bound.size.width * scaleX,
                    height: bound.size.height * scaleY
                )
                context.fill(Path(roundedRect: rect.insetBy(dx: -4, dy: -2), cornerRadius: 5), with: .color(.yellow.opacity(0.38)))
            }
        }
    }
}

private struct PageBackgroundView: View {
    @ObservedObject var session: NotebookSession

    var body: some View {
        switch session.currentBackground {
        case let .template(paper):
            TemplatePageView(paper: paper)
        case .pdf:
            if let url = session.currentBackgroundURL {
                PDFPageBackgroundView(url: url)
            } else {
                Color(uiColor: .systemBackground)
            }
        case nil:
            Color(uiColor: .systemBackground)
        }
    }
}
