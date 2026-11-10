import PencilKit
import SwiftUI

struct PencilCanvasView: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    let session: NotebookSession
    var onDrawingChanged: (PKDrawing) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.delegate = context.coordinator
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.drawingPolicy = .default
        canvas.minimumZoomScale = 1
        canvas.maximumZoomScale = 4
        canvas.drawing = drawing

        let twoFingerUndo = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTwoFingerUndo)
        )
        twoFingerUndo.numberOfTouchesRequired = 2
        canvas.addGestureRecognizer(twoFingerUndo)
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        context.coordinator.parent = self
        if canvas.drawing != drawing {
            context.coordinator.isApplyingExternalDrawing = true
            canvas.drawing = drawing
            context.coordinator.isApplyingExternalDrawing = false
        }

        if canvas.window != nil, context.coordinator.toolPicker == nil {
            let picker = PKToolPicker()
            picker.setVisible(true, forFirstResponder: canvas)
            picker.addObserver(canvas)
            canvas.becomeFirstResponder()
            context.coordinator.toolPicker = picker
            session.attachCanvas(canvas)
        }
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: PencilCanvasView
        var toolPicker: PKToolPicker?
        var isApplyingExternalDrawing = false

        init(parent: PencilCanvasView) { self.parent = parent }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            guard !isApplyingExternalDrawing else { return }
            parent.onDrawingChanged(canvasView.drawing)
        }

        @objc func handleTwoFingerUndo(_ recognizer: UITapGestureRecognizer) {
            (recognizer.view as? PKCanvasView)?.undoManager?.undo()
        }
    }
}
