import QuireCore
import SwiftUI

struct NewNotebookView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var library: LibraryModel
    @State private var title = "Untitled Notebook"
    @State private var kind = PaperKind.lined
    @State private var size = PaperSize.a4

    var body: some View {
        Form {
            Section("Notebook") {
                TextField("Title", text: $title)
            }
            Section("Paper") {
                Picker("Template", selection: $kind) {
                    ForEach(PaperKind.allCases, id: \.self) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }
                Picker("Size", selection: $size) {
                    Text("A4").tag(PaperSize.a4)
                    Text("US Letter").tag(PaperSize.usLetter)
                }
            }
        }
        .navigationTitle("New Notebook")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Create") {
                    Task {
                        if await library.createNotebook(
                            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                            paper: Paper(kind: kind, size: size)
                        ) != nil {
                            dismiss()
                        }
                    }
                }
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}

private extension PaperKind {
    var displayName: String {
        switch self {
        case .blank: "Blank"
        case .lined: "Lined"
        case .grid: "Grid"
        case .dotted: "Dotted"
        case .cornell: "Cornell"
        }
    }
}
