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

extension Picture {
    // A locked frame: a saved video's (blue, green, red, then a spare number) or the live camera's 420 (brightness for
    // every pixel, one color pair for each 2×2 block).
    init(frame: CVPixelBuffer) {
        let width = CVPixelBufferGetWidth(frame), height = CVPixelBufferGetHeight(frame)
        let format = CVPixelBufferGetPixelFormatType(frame)
        var rgb = [UInt8](repeating: 0, count: width * height * 3)
        if format == kCVPixelFormatType_32BGRA {
            let rowLength = CVPixelBufferGetBytesPerRow(frame)
            let pixels = CVPixelBufferGetBaseAddress(frame)!.assumingMemoryBound(to: UInt8.self)
            for y in 0..<height {
                for x in 0..<width {
                    let from = y * rowLength + x * 4, to = (y * width + x) * 3
                    rgb[to] = pixels[from + 2]
                    rgb[to + 1] = pixels[from + 1]
                    rgb[to + 2] = pixels[from]
                }
            }
        } else {
            let fullRange = format == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
            let luma = CVPixelBufferGetBaseAddressOfPlane(frame, 0)!.assumingMemoryBound(to: UInt8.self)
            let chroma = CVPixelBufferGetBaseAddressOfPlane(frame, 1)!.assumingMemoryBound(to: UInt8.self)
            let lumaRow = CVPixelBufferGetBytesPerRowOfPlane(frame, 0), chromaRow = CVPixelBufferGetBytesPerRowOfPlane(frame, 1)
            for y in 0..<height {
                for x in 0..<width {
                    let pair = (y / 2) * chromaRow + x / 2 * 2, to = (y * width + x) * 3
                    let color = Self.rgb(y: luma[y * lumaRow + x], cb: chroma[pair], cr: chroma[pair + 1], fullRange: fullRange)
                    (rgb[to], rgb[to + 1], rgb[to + 2]) = (color.red, color.green, color.blue)
                }
            }
        }
        self.init(width: width, height: height, rgb: rgb)
    }

    // One 420 pixel as red, green and blue, with the camera's color math (BT.709). The 16-to-235 way stretches to 0-255.
    static func rgb(y: UInt8, cb: UInt8, cr: UInt8, fullRange: Bool) -> (red: UInt8, green: UInt8, blue: UInt8) {
        let luma = fullRange ? Double(y) : (Double(y) - 16) * 255 / 219, colorScale = fullRange ? 1.0 : 255.0 / 224
        let blue = (Double(cb) - 128) * colorScale, red = (Double(cr) - 128) * colorScale
        func level(_ value: Double) -> UInt8 { UInt8(min(max(value.rounded(), 0), 255)) }
        return (level(luma + 1.5748 * red), level(luma - 0.1873 * blue - 0.4681 * red), level(luma + 1.8556 * blue))
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
            // A window starting between frames gets the earlier frame with its time changed to the start. Opening early lets the time check below drop it.
            reader.timeRange = CMTimeRange(start: CMTime(seconds: max(start - 0.01, 0), preferredTimescale: 24000),
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

    // Returns the first frame at or after this time.
    static func picture(_ url: URL, at time: Double) async throws -> Picture? {
        var found: Picture?
        do {
            try await eachFrame(url, from: time) { buffer, _ in
                found = Picture(frame: buffer)
                throw FoundFrame()
            }
        } catch is FoundFrame {}
        return found
    }

    private struct FoundFrame: Error {}
}
