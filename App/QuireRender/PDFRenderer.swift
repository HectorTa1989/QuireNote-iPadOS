import PDFKit
import PencilKit
import QuireCore
import UIKit

public struct NotebookPDFRenderer {
    public init() {}

    public func render(notebook: Notebook, drawings: [UUID: PKDrawing], packageURL: URL) throws {
        let firstSize = TemplateGeometry.pageSize(for: notebook.paper)
        let bounds = CGRect(x: 0, y: 0, width: firstSize.width, height: firstSize.height)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)

        let data = renderer.pdfData { context in
            for page in notebook.pages {
                let pageBounds = boundsForPage(page, notebook: notebook, packageURL: packageURL)
                context.beginPage(withBounds: pageBounds, pageInfo: [:])
                drawBackground(page, in: pageBounds, context: context.cgContext, packageURL: packageURL)
                if let drawing = drawings[page.id], !drawing.strokes.isEmpty {
                    drawing.image(from: pageBounds, scale: 2).draw(in: pageBounds)
                }
            }
        }

        let destination = packageURL.appendingPathComponent(
            FileLayout.flattenedPDFName(notebookTitle: notebook.title)
        )
        try CoordinatedFileIO.write(data, to: destination)
    }

    private func boundsForPage(_ page: PageRef, notebook: Notebook, packageURL: URL) -> CGRect {
        switch page.background {
        case let .template(paper):
            let size = TemplateGeometry.pageSize(for: paper)
            return CGRect(x: 0, y: 0, width: size.width, height: size.height)
        case let .pdf(file, pageIndex):
            let url = packageURL.appendingPathComponent(file)
            if let pdfPage = PDFDocument(url: url)?.page(at: pageIndex) {
                return pdfPage.bounds(for: .mediaBox)
            }
            let size = TemplateGeometry.pageSize(for: notebook.paper)
            return CGRect(x: 0, y: 0, width: size.width, height: size.height)
        }
    }

    private func drawBackground(_ page: PageRef, in bounds: CGRect, context: CGContext, packageURL: URL) {
        UIColor.systemBackground.setFill()
        context.fill(bounds)

        switch page.background {
        case let .template(paper):
            drawTemplate(paper, in: bounds, context: context)
        case let .pdf(file, pageIndex):
            guard let pdfPage = PDFDocument(url: packageURL.appendingPathComponent(file))?.page(at: pageIndex) else { return }
            context.saveGState()
            context.translateBy(x: 0, y: bounds.height)
            context.scaleBy(x: 1, y: -1)
            pdfPage.draw(with: .mediaBox, to: context)
            context.restoreGState()
        }
    }

    private func drawTemplate(_ paper: Paper, in bounds: CGRect, context: CGContext) {
        let sourceSize = TemplateGeometry.pageSize(for: paper)
        let scaleX = bounds.width / sourceSize.width
        let scaleY = bounds.height / sourceSize.height

        for line in TemplateGeometry.lines(for: paper) {
            let start = CGPoint(x: line.start.x * scaleX, y: line.start.y * scaleY)
            let end = CGPoint(x: line.end.x * scaleX, y: line.end.y * scaleY)
            switch line.role {
            case .dot:
                context.setFillColor(UIColor.secondaryLabel.withAlphaComponent(0.42).cgColor)
                context.fillEllipse(in: CGRect(x: start.x - 0.75, y: start.y - 0.75, width: 1.5, height: 1.5))
            case .rule, .margin:
                let color = line.role == .margin
                    ? UIColor.systemRed.withAlphaComponent(0.35)
                    : UIColor.systemBlue.withAlphaComponent(0.20)
                context.setStrokeColor(color.cgColor)
                context.setLineWidth(line.role == .margin ? 1 : 0.75)
                context.move(to: start)
                context.addLine(to: end)
                context.strokePath()
            }
        }
    }
}
