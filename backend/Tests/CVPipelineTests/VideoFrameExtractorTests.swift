import Testing
import AVFoundation
import CoreGraphics
@testable import CVPipeline

// Writes a list of frames into a real .mov file in the temp folder, so the test
// knows exactly how many frames the video holds.
func makeVideo(frames: [CGImage], fps: Int32) throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("test-video-\(UUID().uuidString).mov")
    let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
    let settings: [String: Any] = [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: frames[0].width,
        AVVideoHeightKey: frames[0].height,
    ]
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(
        assetWriterInput: input,
        sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: frames[0].width,
            kCVPixelBufferHeightKey as String: frames[0].height,
        ]
    )
    writer.add(input)
    writer.startWriting()
    writer.startSession(atSourceTime: .zero)

    for (i, frame) in frames.enumerated() {
        while !input.isReadyForMoreMediaData { usleep(1000) }
        let buffer = try makePixelBuffer(from: frame, pool: adaptor.pixelBufferPool)
        adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(i), timescale: fps))
    }

    input.markAsFinished()
    let done = DispatchSemaphore(value: 0)
    writer.finishWriting { done.signal() }
    done.wait()
    return url
}

// Copies one frame's pixels into the buffer format video files are built from.
func makePixelBuffer(from frame: CGImage, pool: CVPixelBufferPool?) throws -> CVPixelBuffer {
    var buffer: CVPixelBuffer?
    if let pool {
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
    }
    guard let buffer else { throw NSError(domain: "makePixelBuffer", code: 1) }

    CVPixelBufferLockBaseAddress(buffer, [])
    defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
    let ctx = CGContext(
        data: CVPixelBufferGetBaseAddress(buffer),
        width: frame.width, height: frame.height,
        bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
    )!
    ctx.draw(frame, in: CGRect(x: 0, y: 0, width: frame.width, height: frame.height))
    return buffer
}

@Suite("VideoFrameExtractor")
struct VideoFrameExtractorTests {

    /*
    - Builds a tiny 5-frame video file, then unpacks it
    - This test will expect exactly 5 frames back
    */
    @Test("returns every frame the video contains")
    func extractsAllFrames() async throws {
        let frames = (0..<5).map { i in
            makeFrame(puckAt: CGPoint(x: 100 + 50 * Double(i), y: 100))
        }
        let url = try makeVideo(frames: frames, fps: 30)

        let extracted = try await VideoFrameExtractor().frames(from: url)

        #expect(extracted.count == 5)
    }
}
