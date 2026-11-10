import Foundation
import Testing
@testable import QuireCore

@Suite("Handwriting search index")
struct SearchIndexTests {
    @Test("Search is ordered, case-insensitive, and diacritic-insensitive")
    func normalizedSearch() {
        let first = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let second = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        var index = SearchIndex()
        index.update(pageID: first, text: "The Fourier transform")
        index.update(pageID: second, text: "FOURIÉR series and Fourier analysis")

        let hits = index.search("fourier", pageOrder: [second, first])

        #expect(hits.map(\.pageID) == [second, second, first])
        #expect(hits.map(\.text) == ["FOURIÉR", "Fourier", "Fourier"])
    }

    @Test("Recognition bounds are returned for highlighting")
    func returnsBounds() {
        let pageID = UUID()
        let bounds = [QuireRect(x: 12, y: 24, width: 80, height: 20)]
        var index = SearchIndex()
        index.update(
            pageID: pageID,
            text: "Fourier transform",
            tokens: [RecognitionToken(text: "Fourier", strokeBounds: bounds)]
        )

        let hit = index.search("fourier", pageOrder: [pageID]).first

        #expect(hit?.strokeBounds == bounds)
    }

    @Test("Blank queries produce no results")
    func rejectsBlankQuery() {
        var index = SearchIndex()
        index.update(pageID: UUID(), text: "Anything")
        #expect(index.search("  \n").isEmpty)
    }
}
