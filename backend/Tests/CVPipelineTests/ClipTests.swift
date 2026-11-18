import AVFoundation
import CoreGraphics
import Testing
@testable import CVPipeline

@Suite("Picture")
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
}

@Suite("Clip")
struct ClipTests {
    @Test("every frame comes back")
    func everyFrame() async throws {
        let video = try makeVideo(frames: blankFrames(5), fps: 30)

        #expect(try await frameTimes(video).count == 5)
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
