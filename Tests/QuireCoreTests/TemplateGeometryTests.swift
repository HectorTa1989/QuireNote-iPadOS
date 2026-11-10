import Testing
@testable import QuireCore

@Suite("Paper template geometry")
struct TemplateGeometryTests {
    @Test("A4 dimensions use PDF points")
    func a4Dimensions() {
        let size = TemplateGeometry.pageSize(for: Paper(kind: .blank, size: .a4))
        #expect(abs(size.width - 595.2756) < 0.001)
        #expect(abs(size.height - 841.8898) < 0.001)
    }

    @Test("US Letter dimensions are exact PDF points")
    func letterDimensions() {
        let size = TemplateGeometry.pageSize(for: Paper(kind: .blank, size: .usLetter))
        #expect(size == QuireSize(width: 612, height: 792))
    }

    @Test("Each MVP template has expected structure", arguments: PaperKind.allCases)
    func templateStructure(kind: PaperKind) {
        let paper = Paper(kind: kind, size: .a4)
        let lines = TemplateGeometry.lines(for: paper)

        switch kind {
        case .blank:
            #expect(lines.isEmpty)
        case .lined:
            #expect(!lines.isEmpty)
            #expect(lines.allSatisfy { $0.start.y == $0.end.y && $0.role == .rule })
        case .grid:
            #expect(lines.contains { $0.start.y == $0.end.y })
            #expect(lines.contains { $0.start.x == $0.end.x })
        case .dotted:
            #expect(!lines.isEmpty)
            #expect(lines.allSatisfy { $0.start == $0.end && $0.role == .dot })
        case .cornell:
            #expect(lines.filter { $0.role == .margin }.count == 2)
        }
    }
}
