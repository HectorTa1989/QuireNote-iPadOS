import Foundation
import Testing
@testable import QuireCore

@Suite("Notebook format")
struct NotebookCodecTests {
    @Test("Version 1 round-trips deterministically")
    func roundTrip() throws {
        let pageID = UUID(uuidString: "7A59814A-1B2F-45EA-9AFE-1D68FF05DD04")!
        let notebook = Notebook(
            id: UUID(uuidString: "8C847B3A-25C5-4437-9E0B-2C6BA60AF7B1")!,
            title: "Signals",
            paper: Paper(kind: .grid, size: .a4),
            pages: [
                PageRef(
                    id: pageID,
                    background: .pdf(file: FileLayout.backgroundPDFPath(for: pageID), pageIndex: 2),
                    recognizedText: "Fourier transform",
                    recognizedAt: Date(timeIntervalSince1970: 1_700_000_000)
                ),
            ],
            createdAt: Date(timeIntervalSince1970: 1_690_000_000)
        )

        let firstEncoding = try NotebookCodec.encode(notebook)
        let decoded = try NotebookCodec.decode(firstEncoding)
        let secondEncoding = try NotebookCodec.encode(decoded)

        #expect(decoded == notebook)
        #expect(firstEncoding == secondEncoding)
        #expect(String(decoding: firstEncoding, as: UTF8.self).contains("\"schemaVersion\" : 1"))
    }

    @Test("Future versions are rejected")
    func rejectsFutureVersion() throws {
        let notebook = Notebook(
            title: "Future",
            paper: Paper(kind: .blank, size: .usLetter),
            schemaVersion: 99
        )

        #expect(throws: NotebookFormatError.unsupportedSchemaVersion(99)) {
            try NotebookCodec.encode(notebook)
        }
    }

    @Test("Missing schema versions are rejected")
    func rejectsMissingVersion() {
        let data = Data("{\"title\":\"Legacy\"}".utf8)
        #expect(throws: NotebookFormatError.missingSchemaVersion) {
            try NotebookCodec.decode(data)
        }
    }

    @Test("Package escape paths are rejected")
    func rejectsUnsafePath() {
        let page = PageRef(
            background: .template(Paper(kind: .lined, size: .a4)),
            strokesFile: "../outside.drawing"
        )
        let notebook = Notebook(
            title: "Unsafe",
            paper: Paper(kind: .lined, size: .a4),
            pages: [page]
        )

        #expect(throws: NotebookFormatError.invalidRelativePath("../outside.drawing")) {
            try NotebookCodec.encode(notebook)
        }
    }

    @Test("Duplicate page identities are rejected")
    func rejectsDuplicatePages() {
        let pageID = UUID()
        let paper = Paper(kind: .dotted, size: .a4)
        let pages = [
            PageRef(id: pageID, background: .template(paper)),
            PageRef(id: pageID, background: .template(paper)),
        ]
        let notebook = Notebook(title: "Duplicate", paper: paper, pages: pages)

        #expect(throws: NotebookFormatError.duplicatePageID(pageID)) {
            try NotebookCodec.encode(notebook)
        }
    }
}
