import AVFoundation
import CoreVideo
import Foundation
import Testing
import simd
@testable import CVPipeline

@Suite("LiveShotReader")
struct LiveShotReaderTests {
    // Taking camera pictures

    @Test("the first 8 pictures give nothing, because the spotter needs 9")
    func firstEightPictures() throws {
        let run = try film([firstShot], frames: [204..<212])

        #expect(run.said.isEmpty)
        #expect(run.notes.isEmpty)
    }

    @Test("one shot gives one speed, on the picture at 1.525 s and never again, the same as after Stop")
    func oneShotOnce() throws {
        let run = try film([firstShot], frames: [204..<421])
        let said = try #require(run.said.first)

        #expect(run.said.count == 1)
        #expect(abs(said.time - 366.0 / 240) < 1e-9)
        #expect(run.afterStop.count == 1)
        #expect(said.reading.mph == run.afterStop.first?.mph)
    }

    @Test("two shots give two speeds, in order, the same as after Stop")
    func twoShots() throws {
        let run = try film([firstShot, secondShot], frames: [204..<421, 924..<1141])

        #expect(run.said.count == 2)
        #expect(run.said.map(\.reading.mph) == run.afterStop.map(\.mph))
        #expect(run.said.map(\.time) == run.said.map(\.time).sorted())
    }

    @Test("a picture of the wrong size gives nothing and doesn't crash")
    func wrongSizePicture() throws {
        var made: CVPixelBuffer?
        CVPixelBufferCreate(nil, 1280, 720, kCVPixelFormatType_32BGRA, nil, &made)
        let small = try #require(made)
        var reader = LiveShotReader(lane: lane, pose: phone(), scale: 1)
        var said: [ShotReading] = []
        for index in 0..<20 { said += reader.feed(small, time: Double(index) / 240) }

        #expect(said.isEmpty)
        #expect(reader.notes.isEmpty)
    }

    // Blinks

    @Test("a picture dropped during the shot keeps it quiet, with its speed kept in the note")
    func blinkDuringShot() throws {
        let run = try film([firstShot], frames: [204..<421], dropped: [264])
        let note = try #require(run.notes.first)

        #expect(run.said.isEmpty)
        #expect(note.framesLost == 1)
        #expect(note.reading != nil)
    }

    @Test("3 pictures dropped at 0.5 s, before the shot, don't keep it quiet")
    func blinkBeforeShot() throws {
        #expect(try film([firstShot], frames: [108..<421], dropped: [120, 121, 122]).said.count == 1)
    }

    @Test("a blink during the first shot doesn't keep the next shot quiet")
    func blinkDoesNotSpread() throws {
        let run = try film([firstShot, secondShot], frames: [204..<421, 924..<1141], dropped: [264])

        #expect(run.notes.map(\.said) == [false, true])
        #expect(run.said.count == 1)
        #expect((run.said.first?.time ?? 0) > 4)
    }

    @Test("5 pictures dropped before the very first one don't keep a shot quiet")
    func blinksBeforeFirstPicture() throws {
        #expect(try film([firstShot], frames: [108..<421], droppedBeforeStart: 5).said.count == 1)
    }

    // Handing in darkness directly

    @Test("darkness handed in directly gives the same speed as the camera pictures")
    func darknessHandedIn() throws {
        let fromPictures = try film([firstShot], frames: [204..<421])
        let fromDarkness = try film([firstShot], frames: [204..<421], handInDarkness: true)

        #expect(fromDarkness.said.count == 1)
        #expect(fromDarkness.said.first?.reading.mph == fromPictures.said.first?.reading.mph)
    }

    // Your real videos

    @Test("your 9 Nov 16 videos read live give the same 19 shots as after Stop, each within 0.1 mph",
          .enabled(if: realVideosRequested))
    func nov16LiveMatchesAfterStop() async throws {
        var total = 0
        for clip in try nov16Clips() {
            let url = rinkClips.appendingPathComponent(clip.clip)
            let afterStop = try #require(try await ShotReader.read(url, taps: clip.net.taps, lens: iPhone))
            let live = try await liveSpeeds(url, taps: clip.net.taps, dropping: 0)

            #expect(live.count == afterStop.count, "\(clip.clip)")
            for (one, other) in zip(live, afterStop) {
                #expect(abs(one.releaseTime - other.releaseTime) < 0.05, "\(clip.clip)")
                #expect(abs(one.mph - other.mph) <= 0.1, "\(clip.clip): \(one.mph) live, \(other.mph) after Stop")
            }
            total += live.count
        }
        #expect(total == 19)
    }

    @Test("with 1% of pictures dropped at random, every speed said out loud is still within 0.1 mph of after Stop",
          .enabled(if: realVideosRequested))
    func droppedPicturesNeverGiveAWrongSpeed() async throws {
        for (index, clip) in try nov16Clips().enumerated() {
            let url = rinkClips.appendingPathComponent(clip.clip)
            let afterStop = try #require(try await ShotReader.read(url, taps: clip.net.taps, lens: iPhone))
            let live = try await liveSpeeds(url, taps: clip.net.taps, dropping: 0.01, seed: UInt64(index + 1))

            for one in live {
                #expect(afterStop.contains { abs($0.releaseTime - one.releaseTime) < 0.05 && abs($0.mph - one.mph) <= 0.1 },
                        "\(clip.clip): said \(one.mph)")
            }
        }
    }
}

private typealias Sighting = (t: Double, spot: Vec2)

private let iPhone = Lens(zoom: 1470.2, centerX: 960, centerY: 540)
private let lowShot = Vec3(-6, -192, 16)
private let firstShot = puckSpots(mph: 60, aim: lowShot, release: 1)
private let secondShot = puckSpots(mph: 40, aim: Vec3(10, -192, 30), release: 4)
private let realVideosRequested = ProcessInfo.processInfo.environment["CHEDDAR_REAL_VIDEOS"] == "1"
private let rinkClips = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().appendingPathComponent("videos/rink-clips")

// The search strip around where the pretend shots fly, kept small so the tests stay quick.
private let lane: (rows: Range<Int>, columns: Range<Int>) = {
    let spots = (firstShot + secondShot).map(\.spot)
    let xs = spots.map(\.x), ys = spots.map(\.y)
    return (max(0, Int(ys.min()!) - 30)..<min(1080, Int(ys.max()!) + 31), max(0, Int(xs.min()!) - 30)..<min(1920, Int(xs.max()!) + 31))
}()

private func phone(at spot: Vec3 = Vec3(263, 115, 61.5), aim: Vec3 = Vec3(36, 60, 20)) -> CameraPose {
    let forward = simd_normalize(aim - spot)
    let level = simd_normalize(Vec3(-forward.y, forward.x, 0))
    let down = simd_normalize(Vec3(0, 0, -1) + forward.z * forward)
    return CameraPose(position: spot, toCamera: simd_double3x3(rows: [level, down, forward]), lens: iPhone)
}

// Where the phone sees a made-up shot from 16 ft out, frame by frame (the same flight as the ShotReader tests).
private func puckSpots(mph: Double, aim: Vec3, release: Double) -> [Sighting] {
    let step = 1e-5, camera = phone()
    var spot = Vec3(36, 192, 0.75), velocity = simd_normalize(aim) * mph * 17.6, time = 0.0, frame = 2
    var spots: [Sighting] = []
    while spot.y > -6 && time < 1 {
        if time >= Double(frame) / 240 {
            spots.append((release + Double(frame) / 240, camera.pixel(of: spot)))
            frame += 1
        }
        velocity += step * (Vec3(0, 0, -386.09) - 1.3e-4 * simd_length(velocity) * velocity)
        spot += step * velocity
        time += step
    }
    return spots
}

private struct Filmed {
    var said: [(time: Double, reading: ShotReading)] = []
    var notes: [ShotLogic.Note] = []
    var afterStop: [ShotReading] = []
}

// Films the pretend shots as 1920×1080 pictures, a dark 12×12 puck on light ice, and feeds them to a live reader one at a
// time. The after-Stop answer reads the same pictures the after-Stop way: every spot frame first, then the shots.
private func film(_ shots: [[Sighting]], frames: [Range<Int>], dropped: Set<Int> = [], droppedBeforeStart: Int = 0,
                  handInDarkness: Bool = false) throws -> Filmed {
    var byFrame: [Int: [Vec2]] = [:]
    for (t, spot) in shots.joined() { byFrame[Int((t * 240).rounded()), default: []].append(spot) }
    let camera = try Camera()
    var reader = LiveShotReader(lane: lane, pose: phone(), scale: 1)
    var everyFrame = FastFramesBack(rows: lane.rows, columns: lane.columns)
    var spotFrames: [SpotFrame] = []
    var darkness = [UInt8](repeating: 0, count: lane.rows.count * lane.columns.count)
    var filmed = Filmed()
    if droppedBeforeStart > 0 { reader.noteDropped(droppedBeforeStart) }
    for index in frames.joined() {
        let time = Double(index) / 240
        camera.show(byFrame[index] ?? [])
        CVPixelBufferLockBaseAddress(camera.frame, .readOnly)
        if let spots = everyFrame.add(camera.frame, time: time) { spotFrames.append(spots) }
        if handInDarkness {
            darkness.withUnsafeMutableBufferPointer {
                FastFramesBack.storeDarkness(camera.frame, rows: lane.rows, columns: lane.columns, into: $0.baseAddress!)
            }
        }
        CVPixelBufferUnlockBaseAddress(camera.frame, .readOnly)
        if dropped.contains(index) {
            reader.noteDropped()
            continue
        }
        let said = handInDarkness ? darkness.withUnsafeBufferPointer { reader.feed(darkness: $0.baseAddress!, time: time) }
                                  : reader.feed(camera.frame, time: time)
        filmed.said += said.map { (time, $0) }
    }
    filmed.notes = reader.notes
    filmed.afterStop = ShotReader.shots(in: spotFrames, pose: phone(), scale: 1)
    return filmed
}

// One 1920×1080 picture, repainted where the puck was and is, so each new frame costs a few hundred pixels.
private final class Camera {
    let frame: CVPixelBuffer
    private var drawn: [(x: Int, y: Int)] = []

    init() throws {
        var made: CVPixelBuffer?
        CVPixelBufferCreate(nil, 1920, 1080, kCVPixelFormatType_32BGRA, nil, &made)
        frame = try #require(made)
        CVPixelBufferLockBaseAddress(frame, [])
        memset(CVPixelBufferGetBaseAddress(frame)!, 170, CVPixelBufferGetBytesPerRow(frame) * 1080)
        CVPixelBufferUnlockBaseAddress(frame, [])
    }

    func show(_ spots: [Vec2]) {
        CVPixelBufferLockBaseAddress(frame, [])
        defer { CVPixelBufferUnlockBaseAddress(frame, []) }
        for corner in drawn { paint(corner, 170) }
        drawn = spots.map { (Int($0.x.rounded()) - 6, Int($0.y.rounded()) - 6) }
        for corner in drawn { paint(corner, 20) }
    }

    private func paint(_ corner: (x: Int, y: Int), _ value: UInt8) {
        let pixels = CVPixelBufferGetBaseAddress(frame)!.assumingMemoryBound(to: UInt8.self)
        let rowLength = CVPixelBufferGetBytesPerRow(frame)
        for y in max(corner.y, 0)..<min(corner.y + 12, 1080) {
            for x in max(corner.x, 0)..<min(corner.x + 12, 1920) {
                memset(pixels + y * rowLength + x * 4, Int32(value), 3)
            }
        }
    }
}

private struct TappedClip: Decodable {
    struct Point: Decodable { let x: Double, y: Double }
    struct Net: Decodable {
        let leftTop: Point, rightTop: Point, rightBottom: Point, leftBottom: Point
        var taps: [Vec2] { [leftTop, rightTop, rightBottom, leftBottom].map { Vec2($0.x, $0.y) } }
    }
    let clip: String
    let net: Net
}

private func nov16Clips() throws -> [TappedClip] {
    try JSONDecoder().decode([TappedClip].self, from: Data(contentsOf: rinkClips.appendingPathComponent("1x-measured-nov16/net-corners.json")))
}

// Reads a real video live, the way the camera hands over its frames, and returns the speeds said out loud.
private func liveSpeeds(_ url: URL, taps: [Vec2], dropping rate: Double, seed: UInt64 = 1) async throws -> [ShotReading] {
    var corners = taps
    if let still = try await Clip.picture(url, at: 1.0), let better = NetCorners.refine(taps, picture: still) { corners = better }
    let pose = try #require(CameraPose(corners: corners, lens: iPhone))
    var reader = LiveShotReader(lane: ShotReader.lane(corners: corners, pose: pose), pose: pose, scale: ShotReader.netScale(corners))
    var random = SplitMix(state: seed)
    var said: [ShotReading] = []
    try await eachCameraFrame(url) { frame, time in
        if random.next() < rate {
            reader.noteDropped()
        } else {
            said += reader.feed(frame, time: time)
        }
    }
    return said
}

// Each frame of a video in the camera's own 420 format, with its time.
private func eachCameraFrame(_ url: URL, _ body: (CVPixelBuffer, Double) throws -> Void) async throws {
    let asset = AVURLAsset(url: url)
    guard let track = try await asset.loadTracks(withMediaType: .video).first else { return }
    let duration = try await asset.load(.duration).seconds
    let reader = try AVAssetReader(asset: asset)
    let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
    ])
    output.alwaysCopiesSampleData = false
    reader.add(output)
    reader.startReading()
    var more = true
    while more {
        try autoreleasepool {
            guard let sample = output.copyNextSampleBuffer() else { more = false; return }
            let time = CMSampleBufferGetPresentationTimeStamp(sample).seconds
            guard (0..<duration).contains(time), let frame = CMSampleBufferGetImageBuffer(sample) else { return }
            try body(frame, time)
        }
    }
}

// Repeatable random numbers from 0 to 1.
private struct SplitMix {
    var state: UInt64

    mutating func next() -> Double {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return Double((z ^ (z >> 31)) >> 11) / Double(UInt64(1) << 53)
    }
}
