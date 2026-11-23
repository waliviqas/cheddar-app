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

    // Any distance

    @Test("a phone that sees the net 2× bigger: a 90 mph shot from 8 ft is said live at the same speed as after Stop, and today's limits miss it")
    func closePhone() throws {
        let run = try filmZoomed(2, aim: Vec3(36, 48, 8)) {
            puckSpots(mph: 90, aim: lowShot, release: 1, from: Vec3(36, 96, 0.75), camera: $0)
        }

        #expect(run.today.isEmpty)
        #expect(run.said.count == 1)
        #expect(run.said.map(\.mph) == run.afterStop.map(\.mph))
    }

    @Test("a phone that sees the net half size: a 50 mph shot from 16 ft is said live at the same speed as after Stop, and today's limits miss it")
    func farPhone() throws {
        let run = try filmZoomed(0.5) { puckSpots(mph: 50, aim: lowShot, release: 1, camera: $0) }

        #expect(run.today.isEmpty)
        #expect(run.said.count == 1)
        #expect(run.said.map(\.mph) == run.afterStop.map(\.mph))
    }

    // Starting from the net frame

    @Test("when the posts can't be found, the live reader starts anyway with the taps as tapped")
    func postsNotFound() throws {
        let reader = try #require(LiveShotReader(netFrame: try grayCameraFrame(), taps: nov16FirstTaps, lens: iPhone))

        #expect(reader.corners == nov16FirstTaps)
    }

    @Test("4 taps in a straight line can't be a net, so the live reader doesn't start")
    func tapsInALine() throws {
        #expect(LiveShotReader(netFrame: try grayCameraFrame(), taps: inALine, lens: iPhone) == nil)
    }
}

@Suite("LiveSpeeds")
struct LiveSpeedsTests {
    // Starting with the video

    @Test("a pretend shot before you press record isn't said")
    func beforeRecord() async throws {
        let heard = Heard(), live = pretendLive(heard)
        _ = try filmLive(live, [firstShot], frames: [204..<421])
        await settle()

        #expect(heard.speeds.isEmpty)
        #expect(live.said.isEmpty)
    }

    @Test("when the phone says the video started at 100.000 s, the shot's time matches after Stop within 1 frame")
    func timesLineUp() throws {
        let live = pretendLive(Heard())
        live.start(videoStart: 100)
        let run = try filmLive(live, [firstShot], frames: [204..<421], clock: 100)
        let afterStop = try #require(run.afterStop.first)

        #expect(live.said.count == 1)
        #expect(abs((live.said.first ?? 0) - afterStop.releaseTime) <= 1.0 / 240)
    }

    @Test("on iOS 17 to 18.1, reading starting 12 frames (0.05 s) late still doesn't say the shot twice")
    func lateStart() async throws {
        let heard = Heard(), live = pretendLive(heard)
        live.start(videoStart: nil)
        let run = try filmLive(live, [firstShot], frames: [0..<421], clock: 100, handOverFrom: 12)
        await settle()

        #expect(heard.speeds.count == 1)
        #expect(run.afterStop.count == 1)
        #expect(live.missed(run.afterStop).isEmpty)
    }

    @Test("your 9 Nov 16 videos: the live reader finds the net on the frame 1 s in, past the wobble from tapping record",
          .enabled(if: realVideosRequested))
    func nov16NetFrame() async throws {
        for clip in try nov16Clips() {
            let url = rinkClips.appendingPathComponent(clip.clip)
            let live = LiveSpeeds(taps: clip.net.taps, lens: iPhone, say: Heard().say)
            live.start(videoStart: 0)
            do {
                try await eachCameraFrame(url) { frame, time in
                    guard time < 1.1 else { throw FrameFound() }
                    live.frame(frame, time: time)
                }
            } catch is FrameFound {}
            let netFrame = try #require(try await cameraFrame(url, at: 1.0))
            let oneSecondIn = try #require(LiveShotReader(netFrame: netFrame, taps: clip.net.taps, lens: iPhone))

            #expect(live.corners.count == 4, "\(clip.clip)")
            #expect(live.corners == oneSecondIn.corners, "\(clip.clip)")
        }
    }

    @Test("4 taps in a straight line say nothing and don't crash")
    func badTaps() async throws {
        let heard = Heard(), live = LiveSpeeds(taps: inALine, lens: iPhone, say: heard.say)
        live.start(videoStart: 0)
        _ = try filmLive(live, [firstShot], frames: [204..<421])
        await settle()

        #expect(heard.speeds.isEmpty)
    }

    // Saying each speed

    @Test("one shot is said once, on the frame at 1.525 s, at the same speed as after Stop")
    func oneShot() async throws {
        let heard = Heard(), live = pretendLive(heard)
        live.start(videoStart: 0)
        let run = try filmLive(live, [firstShot], frames: [204..<421])
        await settle()

        #expect(run.saidOn == [366])
        #expect(run.afterStop.count == 1)
        #expect(heard.speeds == run.afterStop.map(\.mph))
    }

    @Test("two shots are both said, in order, once each")
    func twoShots() async throws {
        let heard = Heard(), live = pretendLive(heard)
        live.start(videoStart: 0)
        let run = try filmLive(live, [firstShot, secondShot], frames: [204..<421, 924..<1141])
        await settle()

        #expect(heard.speeds.count == 2)
        #expect(heard.speeds == run.afterStop.map(\.mph))
    }

    @Test("a frame the phone drops during the shot keeps it quiet")
    func droppedFrame() async throws {
        let heard = Heard(), live = pretendLive(heard)
        live.start(videoStart: 0)
        _ = try filmLive(live, [firstShot], frames: [204..<421], dropped: [264])
        await settle()

        #expect(heard.speeds.isEmpty)
        #expect(live.said.isEmpty)
    }

    @Test("frames handed in from the background get said on the main line")
    func saidOnMain() async throws {
        let heard = Heard(), live = pretendLive(heard)
        live.start(videoStart: 0)
        try await onBackground { _ = try filmLive(live, [firstShot], frames: [204..<421]) }
        await settle()

        #expect(heard.speeds.count == 1)
        #expect(heard.onMain == [true])
    }

    @Test("after Stop, a shot in the frames that keep coming isn't said")
    func framesAfterStop() async throws {
        let heard = Heard(), live = pretendLive(heard)
        live.start(videoStart: 0)
        live.stop()
        _ = try filmLive(live, [firstShot], frames: [204..<421])
        await settle()

        #expect(heard.speeds.isEmpty)
    }

    @Test("your Nov 16 video is read at under 4.2 ms a frame on average, fast enough for 240 frames a second",
          .enabled(if: realVideosRequested))
    func keepsUp() async throws {
        let clip = try #require(try nov16Clips().first)
        let live = LiveSpeeds(taps: clip.net.taps, lens: iPhone, say: Heard().say)
        live.start(videoStart: 0)
        let clock = ContinuousClock()
        var spent = Duration.zero, frames = 0
        try await eachCameraFrame(rinkClips.appendingPathComponent(clip.clip)) { frame, time in
            spent += clock.measure { live.frame(frame, time: time) }
            frames += 1
        }

        #expect(frames > 0)
        #expect(spent / max(frames, 1) < .microseconds(4167), "\(spent / max(frames, 1)) a frame over \(frames) frames")
    }

    // After Stop, only the missed shots

    @Test("a shot said live at 2.00 s and read after Stop at 2.00 s isn't said again")
    func sameTime() {
        #expect(LiveSpeeds.missed([reading(at: 2.00)], said: [2.00]).isEmpty)
    }

    @Test("2.00 s live and 2.29 s after Stop are the same shot, so it isn't said again")
    func justInsideTheWindow() {
        #expect(LiveSpeeds.missed([reading(at: 2.29)], said: [2.00]).isEmpty)
    }

    @Test("2.00 s live and 2.31 s after Stop are different shots, so the second is said")
    func justOutsideTheWindow() {
        #expect(LiveSpeeds.missed([reading(at: 2.31)], said: [2.00]).map(\.releaseTime) == [2.31])
    }

    @Test("when nothing was said live, all 3 shots read after Stop are said")
    func nothingSaidLive() {
        let live = pretendLive(Heard())

        #expect(live.missed([reading(at: 1), reading(at: 3), reading(at: 5)]).map(\.releaseTime) == [1, 3, 5])
    }

    @Test("the saved shots keep the live 61.4 said at 2.00 s and add the 58.0 at 5.00 s that live missed")
    func savedShots() {
        let saved = LiveSpeeds.saved([reading(at: 2.05, mph: 61.7), reading(at: 5.00, mph: 58.0)], live: [reading(at: 2.00, mph: 61.4)])

        #expect(saved.map(\.releaseTime) == [2.00, 5.00])
        #expect(saved.map(\.mph) == [61.4, 58.0])
    }

    @Test("Stop tapped at 1.500 s, before the live call due at 1.525 s: the shot is said once, after Stop")
    func stopRightAfterTheShot() async throws {
        let heard = Heard(), live = pretendLive(heard)
        live.start(videoStart: 0)
        let run = try filmLive(live, [firstShot], frames: [204..<361])
        live.stop()
        await settle()

        #expect(heard.speeds.isEmpty)
        #expect(run.afterStop.count == 1)
        #expect(live.missed(run.afterStop).count == 1)
    }

    @Test("your 9 Nov 16 videos: each of the 19 shots is said once and saved once, and the saved speeds miss the radar by 2.68 mph or less on average, no worse than after Stop",
          .enabled(if: realVideosRequested))
    func nov16SavedShots() async throws {
        var found = 0, extras = 0, misses: [Double] = []
        for clip in try nov16Clips() {
            let url = rinkClips.appendingPathComponent(clip.clip)
            let name = URL(fileURLWithPath: clip.clip).deletingPathExtension().lastPathComponent
            let heard = Heard(), live = LiveSpeeds(taps: clip.net.taps, lens: iPhone, say: heard.say)
            live.start(videoStart: 0)
            try await eachCameraFrame(url) { frame, time in live.frame(frame, time: time) }
            live.stop()
            await settle()
            let afterStop = try #require(try await ShotReader.read(url, taps: clip.net.taps, lens: iPhone))
            let saved = live.saved(afterStop), said = live.said

            #expect(heard.speeds.count + live.missed(afterStop).count == saved.count, "\(clip.clip)")
            #expect(saved.filter { said.contains($0.releaseTime) }.map(\.mph) == heard.speeds, "\(clip.clip)")
            var matched = Set<Int>()
            for known in nov16Radar where known.clip == name {
                guard let i = saved.indices.first(where: { !matched.contains($0) && abs(saved[$0].releaseTime - known.start) < 0.3 })
                else { continue }
                matched.insert(i)
                found += 1
                misses.append(abs(saved[i].mph - known.radar))
            }
            extras += saved.count - matched.count
        }

        #expect(found == 19)
        #expect(extras == 0)
        #expect(misses.reduce(0, +) / Double(max(misses.count, 1)) <= 2.68, "\(misses.reduce(0, +) / Double(max(misses.count, 1))) mph")
    }
}

private typealias Sighting = (t: Double, spot: Vec2)

// Each Nov 16 shot's Pocket Radar speed and when it left the stick, in seconds into its clip.
private let nov16Radar: [(clip: String, radar: Double, start: Double)] = [
    ("62mph-55mph", 62, 15.94), ("62mph-55mph", 55, 20.67), ("61mph-57mph-63mph", 61, 10.26), ("61mph-57mph-63mph", 57, 17.85),
    ("61mph-57mph-63mph", 63, 23.84), ("50mph-36mph-59mph", 50, 12.05), ("50mph-36mph-59mph", 36, 17.41), ("50mph-36mph-59mph", 59, 21.52),
    ("30mph-25mph", 30, 18.49), ("30mph-25mph", 25, 23.11), ("67mph-63mph", 67, 19.80), ("67mph-63mph", 63, 23.75),
    ("63mph-62mph", 63, 11.49), ("63mph-62mph", 62, 14.69), ("62mph-72mph", 62, 16.85), ("62mph-72mph", 72, 20.37),
    ("74mph-62mph", 74, 27.10), ("74mph-62mph", 62, 31.65), ("54mph-65mph", 54, 21.28), ("54mph-65mph", 65, 25.59),
]
private let nov16FirstTaps = [Vec2(1579.4, 538.2), Vec2(1812.8, 562.6), Vec2(1806.8, 926.0), Vec2(1575.8, 807.0)]
private let inALine = (0..<4).map { Vec2(500 + 100 * Double($0), 500) }

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

private func phone(at spot: Vec3 = Vec3(263, 115, 61.5), aim: Vec3 = Vec3(36, 60, 20), lens: Lens = iPhone) -> CameraPose {
    let forward = simd_normalize(aim - spot)
    let level = simd_normalize(Vec3(-forward.y, forward.x, 0))
    let down = simd_normalize(Vec3(0, 0, -1) + forward.z * forward)
    return CameraPose(position: spot, toCamera: simd_double3x3(rows: [level, down, forward]), lens: lens)
}

// Where the phone sees a made-up shot from 16 ft out, frame by frame (the same flight as the ShotReader tests).
private func puckSpots(mph: Double, aim: Vec3, release: Double, from start: Vec3 = Vec3(36, 192, 0.75),
                       camera: CameraPose = phone()) -> [Sighting] {
    let step = 1e-5
    var spot = start, velocity = simd_normalize(aim) * mph * 17.6, time = 0.0, frame = 2
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
    private let size: Int  // the puck's width and height in pixels
    private var drawn: [(x: Int, y: Int)] = []

    init(size: Int = 12) throws {
        self.size = size
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
        drawn = spots.map { (Int($0.x.rounded()) - size / 2, Int($0.y.rounded()) - size / 2) }
        for corner in drawn { paint(corner, 20) }
    }

    private func paint(_ corner: (x: Int, y: Int), _ value: UInt8) {
        let pixels = CVPixelBufferGetBaseAddress(frame)!.assumingMemoryBound(to: UInt8.self)
        let rowLength = CVPixelBufferGetBytesPerRow(frame)
        for y in max(corner.y, 0)..<min(corner.y + size, 1080) {
            for x in max(corner.x, 0)..<min(corner.x + size, 1920) {
                memset(pixels + y * rowLength + x * 4, Int32(value), 3)
            }
        }
    }
}

// Films one pretend shot through a lens that makes the net look `zoom` times as big as on Nov 16, with the puck drawn to
// match, then reads it live, after Stop, and after Stop with today's fixed pixel limits.
private func filmZoomed(_ zoom: Double, aim: Vec3 = Vec3(36, 60, 20), shot: (CameraPose) -> [Sighting]) throws
    -> (said: [ShotReading], afterStop: [ShotReading], today: [ShotReading]) {
    let pose = phone(aim: aim, lens: Lens(zoom: 1470.2 * zoom, centerX: 960, centerY: 540))
    let spots = shot(pose)
    let xs = spots.map(\.spot.x), ys = spots.map(\.spot.y)
    try #require(xs.allSatisfy { (20...1900).contains($0) } && ys.allSatisfy { (20...1060).contains($0) })
    let pad = 30 * max(1, zoom)
    let rows = max(0, Int(ys.min()! - pad))..<min(1080, Int(ys.max()! + pad) + 1)
    let columns = max(0, Int(xs.min()! - pad))..<min(1920, Int(xs.max()! + pad) + 1)
    var byFrame: [Int: [Vec2]] = [:]
    for (t, spot) in spots { byFrame[Int((t * 240).rounded()), default: []].append(spot) }
    let camera = try Camera(size: Int((12 * zoom).rounded()))
    var reader = LiveShotReader(lane: (rows, columns), pose: pose, scale: zoom)
    var following = FastFramesBack(rows: rows, columns: columns, scale: zoom), fixed = FastFramesBack(rows: rows, columns: columns)
    var followingFrames: [SpotFrame] = [], fixedFrames: [SpotFrame] = [], said: [ShotReading] = []
    for index in (byFrame.keys.min()! - 48)...(byFrame.keys.max()! + 120) {
        let time = Double(index) / 240
        camera.show(byFrame[index] ?? [])
        CVPixelBufferLockBaseAddress(camera.frame, .readOnly)
        if let spotFrame = following.add(camera.frame, time: time) { followingFrames.append(spotFrame) }
        if let spotFrame = fixed.add(camera.frame, time: time) { fixedFrames.append(spotFrame) }
        CVPixelBufferUnlockBaseAddress(camera.frame, .readOnly)
        said += reader.feed(camera.frame, time: time)
    }
    return (said, ShotReader.shots(in: followingFrames, pose: pose, scale: zoom), todaysShots(fixedFrames, pose: pose, scale: zoom))
}

// The after-Stop read with today's fixed pixel limits, where only the fit limit grows with the net.
private func todaysShots(_ frames: [SpotFrame], pose: CameraPose, scale: Double) -> [ShotReading] {
    let direction = ShotReader.towardNet(pose)
    return ShotFinder.flights(frames, towardNet: direction).compactMap { flight in
        guard let track = PuckTrack.exact(flight, frames: frames, towardNet: direction), let fit = ShotFit.read(track, pose: pose),
              ShotReader.keeps(fit, scale: scale) else { return nil }
        return ShotReading(releaseTime: fit.releaseTime, mph: fit.mph, hit: fit.hit, slid: fit.slid)
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

private struct FilmedLive {
    var saidOn: [Int] = []  // the frames right after which a speed was said
    var afterStop: [ShotReading] = []
}

// Films the pretend shots and hands each frame to LiveSpeeds the way the camera does, on the phone's clock: the frame's
// time in the video plus `clock`. Frames before `handOverFrom` are filmed but never handed over. The after-Stop answer
// reads every filmed frame.
private func filmLive(_ live: LiveSpeeds, _ shots: [[Sighting]], frames: [Range<Int>], clock: Double = 0,
                      handOverFrom: Int = 0, dropped: Set<Int> = []) throws -> FilmedLive {
    var byFrame: [Int: [Vec2]] = [:]
    for (t, spot) in shots.joined() { byFrame[Int((t * 240).rounded()), default: []].append(spot) }
    let camera = try Camera()
    var everyFrame = FastFramesBack(rows: lane.rows, columns: lane.columns)
    var spotFrames: [SpotFrame] = []
    var filmed = FilmedLive()
    for index in frames.joined() {
        let time = Double(index) / 240
        camera.show(byFrame[index] ?? [])
        CVPixelBufferLockBaseAddress(camera.frame, .readOnly)
        if let spots = everyFrame.add(camera.frame, time: time) { spotFrames.append(spots) }
        CVPixelBufferUnlockBaseAddress(camera.frame, .readOnly)
        guard index >= handOverFrom else { continue }
        if dropped.contains(index) {
            live.dropped()
            continue
        }
        let before = live.said.count
        live.frame(camera.frame, time: clock + time)
        if live.said.count > before { filmed.saidOn.append(index) }
    }
    filmed.afterStop = ShotReader.shots(in: spotFrames, pose: phone(), scale: 1)
    return filmed
}

// A LiveSpeeds whose live reader searches the small strip around the pretend shots, so the tests stay quick.
private func pretendLive(_ heard: Heard) -> LiveSpeeds {
    LiveSpeeds(say: heard.say) { _ in LiveShotReader(lane: lane, pose: phone(), scale: 1) }
}

// Stands in for the voice: keeps each speed it's asked to say, and whether it was asked on the main line.
private final class Heard: @unchecked Sendable {
    private let lock = NSLock()
    private var spoken: [Double] = [], mainLine: [Bool] = []

    var speeds: [Double] { lock.withLock { spoken } }
    var onMain: [Bool] { lock.withLock { mainLine } }

    var say: @MainActor @Sendable ([Double]) -> Void {
        { speeds in
            self.lock.withLock {
                self.spoken += speeds
                self.mainLine.append(Thread.isMainThread)
            }
        }
    }
}

// Waits until the main line has done everything it was asked to before now.
private func settle() async {
    await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
        DispatchQueue.main.async { done.resume() }
    }
}

// Runs the work on a background line, the way the camera hands over frames, and waits for it.
private func onBackground(_ work: @escaping @Sendable () throws -> Void) async throws {
    try await withCheckedThrowingContinuation { (done: CheckedContinuation<Void, Error>) in
        DispatchQueue.global().async {
            do {
                try work()
                done.resume()
            } catch {
                done.resume(throwing: error)
            }
        }
    }
}

private func reading(at time: Double, mph: Double = 60) -> ShotReading {
    ShotReading(releaseTime: time, mph: mph, hit: Vec2(36, 24), slid: false)
}

private struct FrameFound: Error {}

// The first frame at or after this time, in the camera's own 420 format.
private func cameraFrame(_ url: URL, at wanted: Double) async throws -> CVPixelBuffer? {
    var found: CVPixelBuffer?
    do {
        try await eachCameraFrame(url) { frame, time in
            guard time >= wanted else { return }
            found = frame
            throw FrameFound()
        }
    } catch is FrameFound {}
    return found
}

// A plain gray 1920×1080 frame in the camera's 420 format: no net to find.
private func grayCameraFrame() throws -> CVPixelBuffer {
    var made: CVPixelBuffer?
    CVPixelBufferCreate(nil, 1920, 1080, kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, nil, &made)
    let frame = try #require(made)
    CVPixelBufferLockBaseAddress(frame, [])
    for plane in 0..<2 {
        memset(CVPixelBufferGetBaseAddressOfPlane(frame, plane)!, 128,
               CVPixelBufferGetBytesPerRowOfPlane(frame, plane) * CVPixelBufferGetHeightOfPlane(frame, plane))
    }
    CVPixelBufferUnlockBaseAddress(frame, [])
    return frame
}

