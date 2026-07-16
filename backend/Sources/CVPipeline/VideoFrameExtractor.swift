import AVFoundation
import CoreGraphics
import CoreImage

/*
This class's only job is: video file in, every frame inside it out as images.
*/
public struct VideoFrameExtractor {
    private let context = CIContext()

    public init() {}

    // Opens the video and pulls out every frame, front to back.
    public func frames(from url: URL) async throws -> [CGImage] {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            return []
        }
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ])
        reader.add(output)
        reader.startReading()

        var frames: [CGImage] = []
        while let sample = output.copyNextSampleBuffer() {
            if let image = makeImage(from: sample) {
                frames.append(image)
            }
        }
        return frames
    }

    // Converts one raw video frame into a normal image.
    private func makeImage(from sample: CMSampleBuffer) -> CGImage? {
        guard let buffer = CMSampleBufferGetImageBuffer(sample) else { return nil }
        let ciImage = CIImage(cvPixelBuffer: buffer)
        return context.createCGImage(ciImage, from: ciImage.extent)
    }
}
