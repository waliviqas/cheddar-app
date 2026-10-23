import Testing
import AVFoundation
import CoreGraphics
@testable import CVPipeline

// Writes a list of frames into a real .mov file in the temp folder, so the test
// knows exactly how many frames the video holds.
// `ticks` says which 1/fps slot each frame lands on; leave it out for evenly spaced frames.
func makeVideo(frames: [CGImage], fps: Int32, ticks: [Int]? = nil) throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("test-video-\(UUID().uuidString).mov")
    let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
    let settings: [String: Any] = [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: frames[0].width,
        AVVideoHeightKey: frames[0].height,
    ]
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
    // Store times in 1/fps units so frame times are saved exactly, not rounded.
    input.mediaTimeScale = fps
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
        adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(ticks?[i] ?? i), timescale: fps))
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

    /*
    - Builds a tiny 240fps video with 4 frames at 0, 1/240, 2/240, and 5/240 seconds
    - The jump from 2/240 to 5/240 is like the phone skipping two frames
    - This test will expect those exact 4 times back, not evenly spaced ones
    */
    @Test("reads each frame's real time, even when frames were skipped")
    func readsRealFrameTimes() async throws {
        let frames = (0..<4).map { i in
            makeFrame(puckAt: CGPoint(x: 100 + 50 * Double(i), y: 100))
        }
        let url = try makeVideo(frames: frames, fps: 240, ticks: [0, 1, 2, 5])

        let times = try await VideoFrameExtractor().times(from: url)

        let expected = [0.0, 1.0 / 240, 2.0 / 240, 5.0 / 240]
        #expect(times.count == 4)
        #expect(zip(times, expected).allSatisfy { abs($0 - $1) < 0.0001 })
    }
}
