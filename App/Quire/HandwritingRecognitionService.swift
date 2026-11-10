@preconcurrency import CoreGraphics
import QuireCore
@preconcurrency import Vision

struct RecognitionOutput: Sendable {
    var text: String
    var tokens: [RecognitionToken]
}

struct HandwritingRecognitionService: Sendable {
    func recognize(image: CGImage, pageSize: QuireSize) async throws -> RecognitionOutput {
        try await Task.detached(priority: .utility) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            let handler = VNImageRequestHandler(cgImage: image, orientation: .up)
            try handler.perform([request])

            let observations = request.results ?? []
            let lines = observations.compactMap { observation -> (String, QuireRect)? in
                guard let candidate = observation.topCandidates(1).first else { return nil }
                let box = observation.boundingBox
                let bounds = QuireRect(
                    x: box.minX * pageSize.width,
                    y: (1 - box.maxY) * pageSize.height,
                    width: box.width * pageSize.width,
                    height: box.height * pageSize.height
                )
                return (candidate.string, bounds)
            }

            return RecognitionOutput(
                text: lines.map(\.0).joined(separator: "\n"),
                tokens: lines.map { RecognitionToken(text: $0.0, strokeBounds: [$0.1]) }
            )
        }.value
    }
}
