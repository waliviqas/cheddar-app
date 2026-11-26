import CoreML
import CVPipeline
import Vision

/*
This file's only job is: show a camera frame to the trained net finder (NetFinder.mlmodel) and hand back the player's 4
taps moved onto the corners it found near them, so the snap starts from the real corners.
*/
enum ModelCorners {
    private static let model = try? VNCoreMLModel(for: NetFinder(configuration: MLModelConfiguration()).model)

    // Loads the model before the first snap needs it.
    static func load() {
        _ = model
    }

    // The taps, in video pixels, moved onto the corners the model found near them.
    static func nudge(_ taps: [Vec2], in frame: CVPixelBuffer) -> [Vec2] {
        guard let model else { return taps }
        let request = VNCoreMLRequest(model: model)
        request.imageCropAndScaleOption = .scaleFill  // the whole picture, so corners near its edges aren't cropped off
        try? VNImageRequestHandler(cvPixelBuffer: frame, orientation: .up).perform([request])
        let size = Vec2(Double(CVPixelBufferGetWidth(frame)), Double(CVPixelBufferGetHeight(frame)))
        let finds: [(label: String, spot: Vec2)] = (request.results as? [VNRecognizedObjectObservation] ?? []).compactMap { found in
            found.labels.first.map { (label: $0.identifier, spot: FoundCorners.spot(of: found.boundingBox, in: size)) }
        }
        return FoundCorners.nudge(taps, toward: finds)
    }
}
