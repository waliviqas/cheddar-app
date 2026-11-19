import AVFoundation
import CoreGraphics
import CoreVideo
import Foundation

func makeVideo(frames: [CGImage], fps: Int32, ticks: [Int]? = nil, hiddenLeading: Int = 0) throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("test-video-\(UUID().uuidString).mov")
    let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
    let settings: [String: Any] = [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: frames[0].width,
        AVVideoHeightKey: frames[0].height,
    ]
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
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
    writer.startSession(atSourceTime: CMTime(value: CMTimeValue(hiddenLeading), timescale: fps))

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
