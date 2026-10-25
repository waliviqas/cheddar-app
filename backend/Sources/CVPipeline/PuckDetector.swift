import CoreGraphics
import CoreML
import Foundation
import Vision

/*
This struct's only job is: Frame in, the box of every puck the trained model sees out.
*/
public struct PuckDetector {
    // The model learned on 320px squares, so frames are looked at in squares that size.
    private static let square = 320
    private static let step = 240

    // Compiled once and shared, since compiling the model takes a moment.
    nonisolated(unsafe) private static let model: VNCoreMLModel? = {
        guard let url = Bundle.module.url(forResource: "PuckModel", withExtension: "mlmodel"),
              let compiled = try? MLModel.compileModel(at: url),
              let ml = try? MLModel(contentsOf: compiled) else { return nil }
        return try? VNCoreMLModel(for: ml)
    }()

    public init() {}

    // Looks at the frame in overlapping squares and returns every puck box in pixels, y measured from the bottom.
    // A puck seen by two overlapping squares counts once.
    public func pucks(in frame: CGImage) -> [CGRect] {
        guard let model = Self.model else { return [] }
        var found: [(box: CGRect, confidence: Float)] = []

        for top in starts(along: frame.height) {
            for left in starts(along: frame.width) {
                let size = Self.square
                guard let crop = frame.cropping(to: CGRect(x: left, y: top, width: size, height: size)) else { continue }
                let request = VNCoreMLRequest(model: model)
                request.imageCropAndScaleOption = .scaleFill
                try? VNImageRequestHandler(cgImage: crop).perform([request])

                let bottom = Double(frame.height - top - crop.height)
                for case let o as VNRecognizedObjectObservation in request.results ?? [] {
                    let b = o.boundingBox
                    found.append((CGRect(x: Double(left) + b.minX * Double(crop.width),
                                         y: bottom + b.minY * Double(crop.height),
                                         width: b.width * Double(crop.width),
                                         height: b.height * Double(crop.height)), o.confidence))
                }
            }
        }

        var pucks: [CGRect] = []
        for f in found.sorted(by: { $0.confidence > $1.confidence })
        where !pucks.contains(where: { abs($0.midX - f.box.midX) < 15 && abs($0.midY - f.box.midY) < 15 }) {
            pucks.append(f.box)
        }
        return pucks
    }

    // Where each square starts along one side, overlapping, with the last one flush against the edge.
    private func starts(along length: Int) -> [Int] {
        guard length > Self.square else { return [0] }
        var s = Array(stride(from: 0, through: length - Self.square, by: Self.step))
        if s.last != length - Self.square { s.append(length - Self.square) }
        return s
    }
}
