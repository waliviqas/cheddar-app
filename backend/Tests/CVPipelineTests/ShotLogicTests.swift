import Foundation
import Testing
import simd
@testable import CVPipeline

@Suite("ShotLogic")
struct ShotLogicTests {
    // Ignoring a shaky phone

    @Test("5,000 changed pixels still counts as a steady phone, and 5,001 is skipped")
    func bumpLimit() {
        let shot = puckSpots(mph: 60, aim: lowShot, release: 2)

        #expect(notes(spotFrames([shot]) { _, hasPuck in hasPuck ? 5_000 : 0 }).count == 1)
        #expect(notes(spotFrames([shot]) { _, hasPuck in hasPuck ? 5_001 : 0 }).isEmpty)
    }

    @Test("a busy scene raises the limit: after 2 s at 600 changed pixels, 5,500 still counts and 6,001 doesn't")
    func busyScene() {
        let shot = puckSpots(mph: 60, aim: lowShot, release: 2)

        #expect(notes(spotFrames([shot]) { _, hasPuck in hasPuck ? 5_500 : 600 }).count == 1)
        #expect(notes(spotFrames([shot]) { _, hasPuck in hasPuck ? 6_001 : 600 }).isEmpty)
    }

    @Test("a shake in the first second is skipped, so tapping Record isn't a shot")
    func shakyStart() {
        let trail = straightTrail(from: farEdge + direction * 150, pixelsPerFrame: 30, frames: 24, firstFrame: 0)

        #expect(notes(spotFrames([trail])).count == 1)
        #expect(notes(spotFrames([trail]) { index, _ in index < 24 ? 20_000 : 0 }).isEmpty)
    }

    // Following the puck

    @Test("one made-up 60 mph shot gives one speed: 59.83 mph, released at 1 s, hitting 35.2 in across and 11.4 in up")
    func oneShot() throws {
        let all = notes(spotFrames([pretendShot]))
        let note = try #require(all.first)
        let reading = try #require(note.reading)

        #expect(all.count == 1)
        #expect(abs(reading.mph - 59.83) <= 0.01)
        #expect(abs(reading.releaseTime - 1) <= 0.0005)
        #expect(simd_distance(reading.hit, Vec2(35.2, 11.4)) <= 0.1)
        #expect(note.kept && note.said)
    }

    @Test("a puck hidden for 2 frames is still one shot, read the same as after Stop")
    func hiddenBriefly() {
        let frames = spotFrames([pretendShot], hiding: [260, 261])
        let live = notes(frames), afterStop = ShotReader.shots(in: frames, pose: phone(), scale: 1)

        #expect(live.count == 1)
        #expect(afterStop.count == 1)
        #expect(live.first?.reading?.mph == afterStop.first?.mph)
    }

    @Test("a puck hidden for 0.05 s splits its trail in two but is still one shot, like after Stop")
    func hiddenLonger() {
        let start = farEdge + direction * 150
        let first = straightTrail(from: start, pixelsPerFrame: 25, frames: 25, firstFrame: 240)
        let second = straightTrail(from: start + direction * 25 * 37, pixelsPerFrame: 25, frames: 25, firstFrame: 277)
        let frames = spotFrames([first, second])

        #expect(notes(frames).count == 1)
        #expect(ShotFinder.flights(frames, towardNet: direction).count == 1)
    }

    @Test("two shots in a row come out in order: 59.83, then 39.66 mph")
    func twoShots() {
        let live = notes(spotFrames([pretendShot, puckSpots(mph: 40, aim: Vec3(10, -192, 30), release: 4)]))

        #expect(live.count == 2)
        #expect(zip(live.compactMap { $0.reading?.mph }, [59.83, 39.66]).allSatisfy { abs($0 - $1) <= 0.01 })
    }

    @Test("a puck flying back out of the net isn't a shot")
    func flyingBackOut() {
        let going = zip(pretendShot.map(\.t), pretendShot.reversed().map(\.spot)).map { (t: $0, spot: $1) }

        #expect(notes(spotFrames([going])).isEmpty)
    }

    @Test("6 seconds with no puck give no shots")
    func noPuck() {
        #expect(notes(spotFrames([])).isEmpty)
    }

    // Waiting until the shot is over

    @Test("the speed is ready on the first frame at or after 1.508 s, half a second after the puck is first seen")
    func readyHalfASecondAfterFirstSeen() throws {
        let decided = try #require(firstDecision(spotFrames([pretendShot])))

        #expect(abs(decided.time - 362.0 / 240) < 1e-9)
        #expect(!decided.note.capped)
    }

    @Test("a fast spot near the strip's net-side edge, with under 600 px of room, doesn't hold the speed back")
    func spotNearEdgeDoesNotHold() throws {
        let stick = straightTrail(from: netEdge - direction * 300, pixelsPerFrame: 1000.0 / 240, frames: 72, firstFrame: 336,
                                  y: clear(of: pretendShot))
        let decided = try #require(firstDecision(spotFrames([pretendShot, stick])))

        #expect(abs(decided.time - 362.0 / 240) < 1e-9)
        #expect(!decided.note.capped)
    }

    @Test("a spot that might still join the shot holds the speed back, but only 0.15 s more")
    func capHoldsAtMostAFraction() throws {
        let decided = try #require(firstDecision(spotFrames([pretendShot, rollingPuck])))

        #expect(decided.time >= 1.658333 - 1e-6)
        #expect(decided.time <= 1.658333 + 1.0 / 240 + 1e-6)
        #expect(decided.note.capped)
    }

    @Test("that spot doesn't become a second shot")
    func noSecondShot() {
        #expect(notes(spotFrames([pretendShot, rollingPuck])).count == 1)
    }

    // Working out the speed and writing the note

    @Test("a shot that misses wide is noted as missed and not said")
    func wideMiss() throws {
        let all = notes(spotFrames([puckSpots(mph: 50, aim: Vec3(40, -192, 16), release: 2.5)]))
        let note = try #require(all.first)

        #expect(all.count == 1)
        #expect(!note.kept && !note.said)
        #expect(try #require(note.reading).hit.x > 72)
    }

    @Test("a slide at 900 px a second, too slow for the speed math, is noted with no speed and not said")
    func tooSlowToMeasure() throws {
        let slide = straightTrail(from: farEdge + direction * 150, pixelsPerFrame: 900.0 / 240, frames: 193, firstFrame: 240)
        let note = try #require(notes(spotFrames([slide])).first)

        #expect(note.reading == nil)
        #expect(!note.kept && !note.said)
    }

    @Test("a shot 10 minutes into a session still reads 59.83 mph")
    func tenMinutesIn() throws {
        let frames = spotFrames([puckSpots(mph: 60, aim: lowShot, release: 600)], seconds: 606)
        let reading = try #require(notes(frames).first?.reading)

        #expect(abs(reading.mph - 59.83) <= 0.01)
    }

    // Staying quiet when the camera blinks

    @Test("with no pictures dropped, the speed is said")
    func noBlinks() throws {
        let note = try #require(notes(spotFrames([pretendShot])).first)

        #expect(note.framesLost == 0)
        #expect(note.said)
    }

    @Test("a picture dropped at 0.5 s, long before the shot, doesn't hold it back")
    func blinkLongBefore() throws {
        let note = try #require(notes(spotFrames([pretendShot]), lost: [120]).first)

        #expect(note.framesLost == 0)
        #expect(note.said)
    }

    @Test("a picture dropped during the shot holds it back but keeps its speed in the note")
    func blinkDuringShot() throws {
        let note = try #require(notes(spotFrames([pretendShot]), lost: [264]).first)

        #expect(note.framesLost == 1)
        #expect(!note.said)
        #expect(note.kept && note.reading != nil)
    }

    @Test("losing picture 207 holds the shot back, and losing picture 206 doesn't")
    func blinkCutoff() throws {
        #expect(try #require(notes(spotFrames([pretendShot]), lost: [207]).first).framesLost == 1)
        #expect(try #require(notes(spotFrames([pretendShot]), lost: [206]).first).framesLost == 0)
    }

    @Test("a picture lost in the piece of the trail that isn't used still holds the shot back")
    func blinkInUnusedPiece() throws {
        let start = farEdge + direction * 150
        let slow = straightTrail(from: start, pixelsPerFrame: 1000.0 / 240, frames: 157, firstFrame: 240)
        let fast = straightTrail(from: start + direction * 700, pixelsPerFrame: 25, frames: 37, firstFrame: 409)
        let note = try #require(notes(spotFrames([slow, fast]), lost: [288]).first)

        #expect(note.framesLost == 1)
        #expect(!note.said)
    }
}

private typealias Sighting = (t: Double, spot: Vec2)

private let iPhone = Lens(zoom: 1470.2, centerX: 960, centerY: 540)
private let lowShot = Vec3(-6, -192, 16)
private let pretendShot = puckSpots(mph: 60, aim: lowShot, release: 1)

// A second puck heading for the net at 3,000 px a second from 1.45 s to 1.70 s, with room to keep going.
private let rollingPuck = straightTrail(from: netEdge - direction * 1500, pixelsPerFrame: 12.5, frames: 61, firstFrame: 348,
                                        y: clear(of: pretendShot))

private var direction: Double { ShotReader.towardNet(phone()) }

private var laneX: ClosedRange<Double> {
    let columns = ShotReader.lane(corners: netCorners(phone()), pose: phone()).columns
    return Double(columns.lowerBound)...Double(columns.upperBound)
}

private var netEdge: Double { direction > 0 ? laneX.upperBound : laneX.lowerBound }
private var farEdge: Double { direction > 0 ? laneX.lowerBound : laneX.upperBound }

private func phone(at spot: Vec3 = Vec3(263, 115, 61.5), aim: Vec3 = Vec3(36, 60, 20)) -> CameraPose {
    let forward = simd_normalize(aim - spot)
    let level = simd_normalize(Vec3(-forward.y, forward.x, 0))
    let down = simd_normalize(Vec3(0, 0, -1) + forward.z * forward)
    return CameraPose(position: spot, toCamera: simd_double3x3(rows: [level, down, forward]), lens: iPhone)
}

private func netCorners(_ phone: CameraPose) -> [Vec2] {
    [Vec3(0, 0, 48), Vec3(72, 0, 48), Vec3(72, 0, 0), Vec3(0, 0, 0)].map { phone.pixel(of: $0) }
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

// A spot moving straight toward the net in the picture, one sighting per frame.
private func straightTrail(from start: Double, pixelsPerFrame: Double, frames: Int, firstFrame: Int, y: Double = 700) -> [Sighting] {
    (0..<frames).map { (Double(firstFrame + $0) / 240, Vec2(start + direction * pixelsPerFrame * Double($0), y)) }
}

private func clear(of shot: [Sighting]) -> Double {
    (shot.map(\.spot.y).max() ?? 500) + 200
}

private func spotFrames(_ shots: [[Sighting]], seconds: Double = 6, hiding: Set<Int> = [],
                        changed: (Int, Bool) -> Int = { _, _ in 0 }) -> [SpotFrame] {
    var byFrame: [Int: [Spot]] = [:]
    for (t, spot) in shots.joined() {
        byFrame[Int((t * 240).rounded()), default: []].append(Spot(x: spot.x, y: spot.y, size: 200))
    }
    return (0..<Int(seconds * 240)).map { index in
        let spots = hiding.contains(index) ? [] : byFrame[index] ?? []
        return SpotFrame(time: Double(index) / 240, spots: spots, changed: changed(index, byFrame[index] != nil))
    }
}

private func makeLogic() -> ShotLogic {
    ShotLogic(pose: phone(), scale: 1, laneX: laneX)
}

// Feeds every frame, leaving out the lost ones the way a dropped camera frame never arrives, and returns the notes.
private func notes(_ frames: [SpotFrame], lost: Set<Int> = []) -> [ShotLogic.Note] {
    var logic = makeLogic()
    var lastFed = -Double.infinity, lostSinceLast = 0
    for (index, frame) in frames.enumerated() {
        if lost.contains(index) {
            lostSinceLast += 1
            continue
        }
        if lostSinceLast > 0 {
            logic.noteGap(from: lastFed, to: frame.time, lost: lostSinceLast)
            lostSinceLast = 0
        }
        logic.feed(frame, frameTime: frame.time)
        lastFed = frame.time
    }
    return logic.notes
}

private func firstDecision(_ frames: [SpotFrame]) -> (time: Double, note: ShotLogic.Note)? {
    var logic = makeLogic()
    for frame in frames {
        logic.feed(frame, frameTime: frame.time)
        if let note = logic.notes.first { return (frame.time, note) }
    }
    return nil
}
