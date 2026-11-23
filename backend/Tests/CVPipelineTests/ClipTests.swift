import AVFoundation
import CoreGraphics
import Testing
@testable import CVPipeline

@Suite("Picture", .serialized)
struct PictureTests {
    let picture = Picture(width: 2, height: 2, rgb: [
        255, 0, 0, 0, 255, 0,
        0, 0, 255, 255, 255, 255,
    ])

    @Test("reads the color at a spot")
    func readsColor() {
        #expect(isColor(picture.color(1, 0), red: 0, green: 255, blue: 0))
    }

    @Test("the top row stays on top")
    func topRowOnTop() {
        #expect(isColor(picture.color(0, 0), red: 255, green: 0, blue: 0))
        #expect(isColor(picture.color(0, 1), red: 0, green: 0, blue: 255))
    }

    @Test("a spot past the right edge has no color")
    func pastRightEdge() {
        #expect(picture.color(2, 0) == nil)
    }

    @Test("a spot above, left of or below the picture has no color")
    func outsideThePicture() {
        #expect(picture.color(0, -1) == nil)
        #expect(picture.color(-1, 1) == nil)
        #expect(picture.color(0, 2) == nil)
    }

    // Reading the live camera's colors

    @Test("a saved video's pixel, stored blue 10, green 20, red 30, comes out red 30, green 20, blue 10")
    func savedVideoPixel() throws {
        var made: CVPixelBuffer?
        CVPixelBufferCreate(nil, 2, 2, kCVPixelFormatType_32BGRA, nil, &made)
        let frame = try #require(made)
        CVPixelBufferLockBaseAddress(frame, [])
        let pixels = CVPixelBufferGetBaseAddress(frame)!.assumingMemoryBound(to: UInt8.self)
        let spot = CVPixelBufferGetBytesPerRow(frame) + 4
        (pixels[spot], pixels[spot + 1], pixels[spot + 2], pixels[spot + 3]) = (10, 20, 30, 255)
        let picture = Picture(frame: frame)
        CVPixelBufferUnlockBaseAddress(frame, [])

        #expect(isColor(picture.color(1, 1), red: 30, green: 20, blue: 10))
    }

    @Test("16-to-235 way: brightness 16 is pure black and 235 is pure white")
    func videoRangeBlackAndWhite() throws {
        let picture = try cameraPicture(fullRange: false) { x, _ in (x < 2 ? 16 : 235, 128, 128) }

        #expect(isColor(picture.color(0, 0), red: 0, green: 0, blue: 0))
        #expect(isColor(picture.color(2, 0), red: 255, green: 255, blue: 255))
    }

    @Test("16-to-235 way: brightness 0 and 255, past black and white, stay pure black and pure white")
    func videoRangePastBlackAndWhite() throws {
        let picture = try cameraPicture(fullRange: false) { x, _ in (x < 2 ? 0 : 255, 128, 128) }

        #expect(isColor(picture.color(0, 0), red: 0, green: 0, blue: 0))
        #expect(isColor(picture.color(2, 0), red: 255, green: 255, blue: 255))
    }

    @Test("0-to-255 way: brightness 0 is pure black and 255 is pure white")
    func fullRangeBlackAndWhite() throws {
        let picture = try cameraPicture(fullRange: true) { x, _ in (x < 2 ? 0 : 255, 128, 128) }

        #expect(isColor(picture.color(0, 0), red: 0, green: 0, blue: 0))
        #expect(isColor(picture.color(2, 0), red: 255, green: 255, blue: 255))
    }

    @Test("a red post pixel, brightness 66 with colors 109 and 213, comes out red 200, green 30, blue 31")
    func redPost() throws {
        let picture = try cameraPicture(fullRange: true) { _, _ in (66, 109, 213) }

        #expect(isColor(picture.color(0, 0), red: 200, green: 30, blue: 31))
    }

    @Test("all 16.7 million color values come within 1 of the exact math, both ways")
    func everyColor() {
        for fullRange in [true, false] {
            var worst = 0
            for cb in 0...255 {
                for cr in 0...255 {
                    for y in 0...255 {
                        let got = Picture.rgb(y: UInt8(y), cb: UInt8(cb), cr: UInt8(cr), fullRange: fullRange)
                        let exact = exactRGB(y, cb, cr, fullRange: fullRange)
                        worst = max(worst, abs(Int(got.red) - exact.r), abs(Int(got.green) - exact.g), abs(Int(got.blue) - exact.b))
                    }
                }
            }
            #expect(worst <= 1)
        }
    }

    @Test("the pixel at column 1, row 3 uses the color stored for its own 2×2 block")
    func sharedBlockColor() throws {
        // Each 2×2 block gets its own color pair; only the block covering columns 0-1, rows 2-3 is red.
        let picture = try cameraPicture(fullRange: true) { x, y in x / 2 == 0 && y / 2 == 1 ? (66, 109, 213) : (66, 128, 128) }

        #expect(isColor(picture.color(1, 3), red: 200, green: 30, blue: 31))
        #expect(isColor(picture.color(2, 3), red: 66, green: 66, blue: 66))
        #expect(isColor(picture.color(1, 1), red: 66, green: 66, blue: 66))
    }
}

@Suite("Clip", .serialized)
struct ClipTests {
    @Test("every frame comes back")
    func everyFrame() async throws {
        let video = try makeVideo(frames: blankFrames(5), fps: 30)

        #expect(try await frameTimes(video).count == 5)
    }

    // Rough clocks

    @Test("a 240 fps video saved with a rough 1/600 s clock comes back with every frame exactly one frame after the last")
    func roughClock() async throws {
        let ticks = (0..<24).map { Int((Double($0) * 2.5).rounded()) }
        let times = try await frameTimes(try makeVideo(frames: blankFrames(24), fps: 600, ticks: ticks))

        #expect(times.count == 24)
        for (index, step) in zip(times.indices.dropFirst(), zip(times.dropFirst(), times).map { $0 - $1 }) {
            #expect(abs(step - 1.0 / 240) < 0.00001, "frame \(index), step \(step)")
        }
        for (index, time) in times.enumerated() {
            #expect(abs(time - Double(index) / 240) < 0.001, "frame \(index) at \(time)")
        }
    }

    @Test("a frame missing from a rough-clock video keeps its 2-frame gap")
    func roughClockDroppedFrame() async throws {
        let filmed = (0..<24).filter { $0 != 10 }
        let ticks = filmed.map { Int((Double($0) * 2.5).rounded()) }
        let times = try await frameTimes(try makeVideo(frames: blankFrames(23), fps: 600, ticks: ticks))

        #expect(times.count == 23)
        #expect(abs((times[10] - times[9]) - 2.0 / 240) < 0.00001)
    }

    @Test("a video with the Camera app's fine 1/2400 s clock comes back with its times untouched")
    func fineClock() async throws {
        let ticks = (0..<24).map { $0 * 10 }
        let times = try await frameTimes(try makeVideo(frames: blankFrames(24), fps: 2400, ticks: ticks))

        #expect(times == ticks.map { Double($0) / 2400 })
    }

    @Test("frames arrive in time order")
    func timeOrder() async throws {
        let video = try makeVideo(frames: blankFrames(5), fps: 240)

        let times = try await frameTimes(video)

        #expect(times.count == 5)
        #expect(zip(times, times.dropFirst()).allSatisfy { $0 < $1 })
    }

    @Test("dropped frames keep each frame's real time")
    func droppedFrames() async throws {
        let video = try makeVideo(frames: blankFrames(4), fps: 240, ticks: [0, 1, 2, 5])

        #expect(isClose(try await frameTimes(video), to: [0, 1.0 / 240, 2.0 / 240, 5.0 / 240]))
    }

    @Test("leftover frames hidden by a trim are skipped")
    func hiddenLeftovers() async throws {
        let video = try makeVideo(frames: blankFrames(6), fps: 240, hiddenLeading: 2)

        #expect(isClose(try await frameTimes(video), to: [0, 1.0 / 240, 2.0 / 240, 3.0 / 240]))
    }

    @Test("a start and end time return only the frames between them")
    func startAndEnd() async throws {
        let video = try makeVideo(frames: blankFrames(10), fps: 10)

        #expect(isClose(try await frameTimes(video, from: 0.2, to: 0.5), to: [0.2, 0.3, 0.4]))
    }

    @Test("a start time alone reads to the end of the video")
    func startOnly() async throws {
        let video = try makeVideo(frames: blankFrames(10), fps: 10)

        #expect(isClose(try await frameTimes(video, from: 0.7), to: [0.7, 0.8, 0.9]))
    }

    @Test("an end time alone reads from the start of the video")
    func endOnly() async throws {
        let video = try makeVideo(frames: blankFrames(10), fps: 10)

        #expect(isClose(try await frameTimes(video, to: 0.3), to: [0, 0.1, 0.2]))
    }

    @Test("a window past the end of the video returns no frames")
    func pastTheEnd() async throws {
        let video = try makeVideo(frames: blankFrames(10), fps: 10)

        #expect(try await frameTimes(video, from: 5).isEmpty)
    }

    @Test("an end time before the start time returns no frames")
    func endBeforeStart() async throws {
        let video = try makeVideo(frames: blankFrames(10), fps: 10)

        #expect(try await frameTimes(video, from: 0.5, to: 0.2).isEmpty)
    }

    @Test("stopping partway hands over no more frames and reports why")
    func stoppingPartway() async throws {
        let video = try makeVideo(frames: blankFrames(5), fps: 30)
        var handedOver = 0
        var reportedWhy = false

        do {
            try await Clip.eachFrame(video) { _, _ in
                handedOver += 1
                if handedOver == 2 { throw StopReading() }
            }
        } catch is StopReading {
            reportedWhy = true
        }

        #expect(handedOver == 2)
        #expect(reportedWhy)
    }

    @Test("a missing file reports an error")
    func missingFile() async {
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent("missing-\(UUID().uuidString).mov")

        await #expect(throws: (any Error).self) {
            try await Clip.eachFrame(missing) { _, _ in }
        }
    }

    @Test("a file that isn't a video reports an error")
    func notAVideo() async throws {
        let textFile = FileManager.default.temporaryDirectory.appendingPathComponent("not-a-video-\(UUID().uuidString).txt")
        try Data("not a video".utf8).write(to: textFile)

        await #expect(throws: (any Error).self) {
            try await Clip.eachFrame(textFile) { _, _ in }
        }
    }

    @Test("a file with sound but no video returns no frames")
    func soundOnly() async throws {
        #expect(try await frameTimes(try makeSoundFile()).isEmpty)
    }

    @Test("an exact frame time returns that frame")
    func exactFrameTime() async throws {
        let video = try makeVideo(frames: solidFrames([.red, .green, .blue, .white]), fps: 10)

        let found = try #require(try await Clip.picture(video, at: 0.2))

        #expect(isBlue(found.color(32, 32)))
    }

    @Test("a time between two frames returns the next frame")
    func timeBetweenFrames() async throws {
        let video = try makeVideo(frames: solidFrames([.red, .green, .blue, .white]), fps: 10)

        let found = try #require(try await Clip.picture(video, at: 0.15))

        #expect(isBlue(found.color(32, 32)))
    }

    @Test("a time inside a long dropped-frame gap returns the first frame after it")
    func timeInsideGap() async throws {
        let video = try makeVideo(frames: solidFrames([.red, .green, .blue, .white]), fps: 10, ticks: [0, 1, 8, 9])

        let found = try #require(try await Clip.picture(video, at: 0.4))

        #expect(isBlue(found.color(32, 32)))
    }

    @Test("a time past the end of the video returns no picture")
    func timePastTheEnd() async throws {
        let video = try makeVideo(frames: solidFrames([.red, .green, .blue, .white]), fps: 10)

        #expect(try await Clip.picture(video, at: 5) == nil)
    }

    @Test("a negative time returns the first frame")
    func negativeTime() async throws {
        let video = try makeVideo(frames: solidFrames([.red, .green, .blue, .white]), fps: 10)

        let found = try #require(try await Clip.picture(video, at: -1))

        #expect(isRed(found.color(32, 32)))
    }

    @Test("red stays red and blue stays blue")
    func colorsStayCorrect() async throws {
        let video = try makeVideo(frames: solidFrames([.red, .blue]), fps: 10)

        let first = try #require(try await Clip.picture(video, at: 0))
        let second = try #require(try await Clip.picture(video, at: 0.1))

        #expect(isRed(first.color(32, 32)))
        #expect(isBlue(second.color(32, 32)))
    }

    @Test("the picture stays upright and full size")
    func uprightAndFullSize() async throws {
        let video = try makeVideo(frames: [redOverBlueFrame(width: 64, height: 48)], fps: 10)

        let found = try #require(try await Clip.picture(video, at: 0))

        #expect(found.width == 64)
        #expect(found.height == 48)
        #expect(isRed(found.color(32, 4)))
        #expect(isBlue(found.color(32, 43)))
    }

    @Test("a missing file reports an error when grabbing a picture")
    func missingFileForPicture() async {
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent("missing-\(UUID().uuidString).mov")

        await #expect(throws: (any Error).self) {
            try await Clip.picture(missing, at: 0)
        }
    }
}

private enum Paint {
    case red, green, blue, white

    var color: CGColor {
        switch self {
        case .red: CGColor(red: 1, green: 0, blue: 0, alpha: 1)
        case .green: CGColor(red: 0, green: 1, blue: 0, alpha: 1)
        case .blue: CGColor(red: 0, green: 0, blue: 1, alpha: 1)
        case .white: CGColor(red: 1, green: 1, blue: 1, alpha: 1)
        }
    }
}

private func blankContext(width: Int, height: Int) -> CGContext {
    CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
}

private func solidFrames(_ paints: [Paint]) -> [CGImage] {
    paints.map { paint in
        let context = blankContext(width: 64, height: 64)
        context.setFillColor(paint.color)
        context.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
        return context.makeImage()!
    }
}

private func redOverBlueFrame(width: Int, height: Int) -> CGImage {
    let context = blankContext(width: width, height: height)
    context.setFillColor(Paint.blue.color)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height / 2))
    context.setFillColor(Paint.red.color)
    context.fill(CGRect(x: 0, y: height / 2, width: width, height: height - height / 2))
    return context.makeImage()!
}

private func isRed(_ found: (r: Int, g: Int, b: Int)?) -> Bool {
    guard let found else { return false }
    return found.r > 180 && found.g < 90 && found.b < 90
}

private func isBlue(_ found: (r: Int, g: Int, b: Int)?) -> Bool {
    guard let found else { return false }
    return found.b > 180 && found.r < 90 && found.g < 90
}

private struct StopReading: Error {}

private func frameTimes(_ video: URL, from start: Double = 0, to end: Double? = nil) async throws -> [Double] {
    var times: [Double] = []
    try await Clip.eachFrame(video, from: start, to: end) { _, time in times.append(time) }
    return times
}

private func blankFrames(_ count: Int) -> [CGImage] {
    (0..<count).map { index in
        let context = CGContext(
            data: nil, width: 64, height: 64, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(CGColor(gray: Double(index) / Double(count), alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
        return context.makeImage()!
    }
}

private func makeSoundFile() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("sound-\(UUID().uuidString).caf")
    let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
    let file = try AVAudioFile(forWriting: url, settings: format.settings)
    let silence = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4410)!
    silence.frameLength = 4410
    try file.write(from: silence)
    return url
}

private func isClose(_ found: [Double], to answer: [Double]) -> Bool {
    found.count == answer.count && zip(found, answer).allSatisfy { abs($0 - $1) <= 0.0001 }
}

private func isColor(_ found: (r: Int, g: Int, b: Int)?, red: Int, green: Int, blue: Int) -> Bool {
    guard let found else { return false }
    return found.r == red && found.g == green && found.b == blue
}

// A 4×4 frame in the live camera's 420 format, read into a picture. Each pixel gets its brightness; each 2×2 block gets
// the color pair painted on its top-left pixel.
private func cameraPicture(fullRange: Bool, _ paint: (Int, Int) -> (UInt8, UInt8, UInt8)) throws -> Picture {
    var made: CVPixelBuffer?
    let format = fullRange ? kCVPixelFormatType_420YpCbCr8BiPlanarFullRange : kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
    CVPixelBufferCreate(nil, 4, 4, format, nil, &made)
    let frame = try #require(made)
    CVPixelBufferLockBaseAddress(frame, [])
    defer { CVPixelBufferUnlockBaseAddress(frame, []) }
    let luma = CVPixelBufferGetBaseAddressOfPlane(frame, 0)!.assumingMemoryBound(to: UInt8.self)
    let chroma = CVPixelBufferGetBaseAddressOfPlane(frame, 1)!.assumingMemoryBound(to: UInt8.self)
    let lumaRow = CVPixelBufferGetBytesPerRowOfPlane(frame, 0), chromaRow = CVPixelBufferGetBytesPerRowOfPlane(frame, 1)
    for y in 0..<4 {
        for x in 0..<4 {
            let (brightness, cb, cr) = paint(x, y)
            luma[y * lumaRow + x] = brightness
            if x % 2 == 0 && y % 2 == 0 {
                chroma[(y / 2) * chromaRow + x] = cb
                chroma[(y / 2) * chromaRow + x + 1] = cr
            }
        }
    }
    return Picture(frame: frame)
}

// Red, green and blue from the camera's color math (BT.709), done with decimals.
private func exactRGB(_ y: Int, _ cb: Int, _ cr: Int, fullRange: Bool) -> (r: Int, g: Int, b: Int) {
    let yScale = fullRange ? 1.0 : 255.0 / 219, yOffset = fullRange ? 0.0 : 16, cScale = fullRange ? 1.0 : 255.0 / 224
    let luma = (Double(y) - yOffset) * yScale, blue = (Double(cb) - 128) * cScale, red = (Double(cr) - 128) * cScale
    func level(_ value: Double) -> Int { min(max(Int(value.rounded()), 0), 255) }
    return (level(luma + 1.5748 * red), level(luma - 0.1873 * blue - 0.4681 * red), level(luma + 1.8556 * blue))
}
