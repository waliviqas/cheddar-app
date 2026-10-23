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

    // Reads the time stamped on every frame, in seconds, front to back.
    // Only the stamps are read, not the pictures, so this is quick.
    public func times(from url: URL) async throws -> [Double] {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            return []
        }
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
        reader.add(output)
        reader.startReading()

        var times: [Double] = []
        while let sample = output.copyNextSampleBuffer() {
            // Some entries are bookkeeping with no picture in them; only real frames count.
            let time = CMSampleBufferGetPresentationTimeStamp(sample)
            guard CMSampleBufferGetNumSamples(sample) > 0, time.isNumeric else { continue }
            times.append(time.seconds)
        }
        // Unpacked video can come out of storage order, so put the stamps back in playing order.
        return times.sorted()
    }

    // Converts one raw video frame into a normal image.
    private func makeImage(from sample: CMSampleBuffer) -> CGImage? {
        guard let buffer = CMSampleBufferGetImageBuffer(sample) else { return nil }
        let ciImage = CIImage(cvPixelBuffer: buffer)
        return context.createCGImage(ciImage, from: ciImage.extent)
    }
}
