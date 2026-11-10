import QuireCore
import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @EnvironmentObject private var library: LibraryModel
    @EnvironmentObject private var purchases: PurchaseManager
    @State private var isChoosingFolder = false
    @State private var isCreatingNotebook = false
    @State private var isImportingPDF = false
    @State private var isShowingPaywall = false

    private let columns = [GridItem(.adaptive(minimum: 180, maximum: 260), spacing: 24)]

    var body: some View {
        NavigationSplitView {
            List {
                Section("Library") {
                    Label("All Notebooks", systemImage: "books.vertical")
                    Label("Recent", systemImage: "clock")
                }

                Section("Location") {
                    Button {
                        isChoosingFolder = true
                    } label: {
                        Label(library.libraryURL?.lastPathComponent ?? "Choose Folder", systemImage: "folder")
                    }
                }

                Section("Sort") {
                    Picker("Sort notebooks", selection: $library.sortOrder) {
                        Text("Recently Modified").tag(LibrarySort.modified)
                        Text("Title").tag(LibrarySort.title)
                        Text("Page Count").tag(LibrarySort.pageCount)
                    }
                    .pickerStyle(.menu)
                }
            }
            .navigationTitle("Quire")
        } detail: {
            NavigationStack {
                Group {
                    if library.libraryURL == nil {
                        ContentUnavailableView {
                            Label("Your notebooks are files", systemImage: "folder.badge.plus")
                        } description: {
                            Text("Choose a folder in iCloud Drive or On My iPad. Every notebook keeps a readable PDF beside its editable pages.")
                        } actions: {
                            Button("Choose a Folder") { isChoosingFolder = true }
                                .buttonStyle(.borderedProminent)
                        }
                    } else if library.filteredNotebooks.isEmpty {
                        ContentUnavailableView(
                            library.searchText.isEmpty ? "No Notebooks" : "No Results",
                            systemImage: library.searchText.isEmpty ? "book.closed" : "magnifyingglass",
                            description: Text(library.searchText.isEmpty ? "Create your first file-owned notebook." : "Try a different search.")
                        )
                    } else {
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 24) {
                                ForEach(library.filteredNotebooks) { notebook in
                                    NavigationLink(value: notebook) {
                                        NotebookCard(notebook: notebook)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(28)
                        }
                    }
                }
                .navigationTitle("Notebooks")
                .navigationDestination(for: NotebookSummary.self) { summary in
                    NotebookView(packageURL: summary.packageURL)
                }
                .searchable(text: $library.searchText, prompt: "Search notebooks")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        NavigationLink {
                            SettingsView()
                        } label: {
                            Label("Settings", systemImage: "gearshape")
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button {
                                performProGated { isCreatingNotebook = true }
                            } label: {
                                Label("New Notebook", systemImage: "book.closed")
                            }
                            Button {
                                performProGated { isImportingPDF = true }
                            } label: {
                                Label("Import PDF", systemImage: "doc.badge.plus")
                            }
                        } label: {
                            Label("Add", systemImage: "plus")
                        }
                        .disabled(library.libraryURL == nil)
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $isChoosingFolder,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if case let .success(urls) = result, let url = urls.first {
                Task { await library.chooseLibrary(url) }
            } else if case let .failure(error) = result {
                library.errorMessage = error.localizedDescription
            }
        }
        .fileImporter(
            isPresented: $isImportingPDF,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            if case let .success(urls) = result, let url = urls.first {
                Task { _ = await library.importPDF(url) }
            } else if case let .failure(error) = result {
                library.errorMessage = error.localizedDescription
            }
        }
        .sheet(isPresented: $isCreatingNotebook) {
            NewNotebookView()
        }
        .sheet(isPresented: $isShowingPaywall) {
            PaywallView()
        }
        .alert("Quire couldn’t complete that action", isPresented: errorIsPresented) {
            Button("OK") { library.errorMessage = nil }
        } message: {
            Text(library.errorMessage ?? "Unknown error")
        }
        .overlay {
            if library.isLoading {
                ProgressView()
                    .padding(20)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { library.errorMessage != nil },
            set: { if !$0 { library.errorMessage = nil } }
        )
    }

    private func performProGated(_ action: () -> Void) {
        if library.notebooks.count >= 3 && !purchases.isPro {
            isShowingPaywall = true
        } else {
            action()
        }
    }
}

private struct NotebookCard: View {
    let notebook: NotebookSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RoundedRectangle(cornerRadius: 18)
                .fill(.tint.gradient)
                .aspectRatio(0.75, contentMode: .fit)
                .overlay(alignment: .bottomLeading) {
                    Image(systemName: "scribble.variable")
                        .font(.system(size: 32))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(18)
                }

            Text(notebook.title)
                .font(.headline)
                .lineLimit(1)
            Text("\(notebook.pageCount) page\(notebook.pageCount == 1 ? "" : "s")")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}
