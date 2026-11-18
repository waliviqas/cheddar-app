import AVFoundation

/*
This class's only job is: hold one video frame's colors and say what color is at a spot.

Row 0 is the top of the picture. Every pixel is 3 numbers in a row: red, green, blue.
*/
struct Picture {
    let width: Int, height: Int
    let rgb: [UInt8]

    func color(_ x: Int, _ y: Int) -> (r: Int, g: Int, b: Int)? {
        guard (0..<width).contains(x), (0..<height).contains(y) else { return nil }
        let i = (y * width + x) * 3
        return (Int(rgb[i]), Int(rgb[i + 1]), Int(rgb[i + 2]))
    }
}

/*
This class's only job is: hand over a video's frames one at a time, each with the exact time it was filmed.
*/
enum Clip {
    static func eachFrame(_ url: URL, from start: Double = 0, to end: Double? = nil,
                          _ body: (CVPixelBuffer, Double) throws -> Void) async throws {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else { return }
        let duration = try await asset.load(.duration).seconds
        let last = min(end ?? duration, duration)
        guard start < last else { return }

        let reader = try AVAssetReader(asset: asset)
        if start > 0 || end != nil {
            reader.timeRange = CMTimeRange(start: CMTime(seconds: start, preferredTimescale: 24000),
                                           end: CMTime(seconds: last, preferredTimescale: 24000))
        }
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ])
        output.alwaysCopiesSampleData = false
        reader.add(output)
        reader.startReading()

        var more = true
        while more {
            try autoreleasepool {
                guard let sample = output.copyNextSampleBuffer() else { more = false; return }
                let time = CMSampleBufferGetPresentationTimeStamp(sample)
                guard time.isNumeric, (start..<last).contains(time.seconds),
                      let buffer = CMSampleBufferGetImageBuffer(sample) else { return }
                CVPixelBufferLockBaseAddress(buffer, .readOnly)
                defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
                try body(buffer, time.seconds)
            }
        }
        if reader.status == .failed { throw reader.error ?? CocoaError(.fileReadCorruptFile) }
    }
}
