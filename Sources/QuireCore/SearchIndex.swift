import Foundation

public struct RecognitionToken: Codable, Equatable, Sendable {
    public var text: String
    public var strokeBounds: [QuireRect]

    public init(text: String, strokeBounds: [QuireRect] = []) {
        self.text = text
        self.strokeBounds = strokeBounds
    }
}

public struct SearchHit: Equatable, Sendable {
    public let pageID: UUID
    public let range: Range<String.Index>
    public let strokeBounds: [QuireRect]
    public let text: String

    public init(pageID: UUID, range: Range<String.Index>, strokeBounds: [QuireRect], text: String) {
        self.pageID = pageID
        self.range = range
        self.strokeBounds = strokeBounds
        self.text = text
    }
}

public struct SearchIndex: Codable, Equatable, Sendable {
    public struct Page: Codable, Equatable, Sendable {
        public var text: String
        public var tokens: [RecognitionToken]

        public init(text: String, tokens: [RecognitionToken] = []) {
            self.text = text
            self.tokens = tokens
        }
    }

    private var pages: [UUID: Page]

    public init(pages: [UUID: Page] = [:]) {
        self.pages = pages
    }

    public mutating func update(pageID: UUID, text: String, tokens: [RecognitionToken] = []) {
        pages[pageID] = Page(text: text, tokens: tokens)
    }

    public mutating func remove(pageID: UUID) {
        pages.removeValue(forKey: pageID)
    }

    public func page(for id: UUID) -> Page? {
        pages[id]
    }

    public func search(_ query: String, pageOrder: [UUID]? = nil) -> [SearchHit] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return [] }

        let order = pageOrder ?? pages.keys.sorted { $0.uuidString < $1.uuidString }
        return order.flatMap { pageID -> [SearchHit] in
            guard let page = pages[pageID] else { return [] }
            return matches(in: page, pageID: pageID, query: needle)
        }
    }

    private func matches(in page: Page, pageID: UUID, query: String) -> [SearchHit] {
        var results: [SearchHit] = []
        var remaining = page.text.startIndex..<page.text.endIndex
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]

        while let range = page.text.range(of: query, options: options, range: remaining) {
            let matchedText = String(page.text[range])
            let bounds = page.tokens
                .filter { $0.text.range(of: query, options: options) != nil }
                .flatMap(\.strokeBounds)
            results.append(SearchHit(pageID: pageID, range: range, strokeBounds: bounds, text: matchedText))
            guard range.upperBound < page.text.endIndex else { break }
            remaining = range.upperBound..<page.text.endIndex
        }

        return results
    }
}
