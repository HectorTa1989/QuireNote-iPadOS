import PDFKit
import SwiftUI

struct PDFPageBackgroundView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.displayMode = .singlePage
        view.displayDirection = .vertical
        view.autoScales = true
        view.isUserInteractionEnabled = false
        view.backgroundColor = .systemBackground
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        if view.document?.documentURL != url {
            view.document = PDFDocument(url: url)
            view.goToFirstPage(nil)
        }
    }
}
