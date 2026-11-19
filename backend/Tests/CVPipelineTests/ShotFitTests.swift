import Foundation
import Testing
import simd
@testable import CVPipeline

@Suite("ShotFit")
struct ShotFitTests {
    @Test("a puck with nothing pulling on it flies in a straight line")
    func straightLine() {
        #expect(isClose(ShotFit.simulate(shootingSpot, Vec3(0, -1000, 0), pull: 0, at: [0.1], drag: 0), [Vec3(36, 92, 0.75)]))
    }

    @Test("a frame time between the math's small steps lands exactly")
    func oneFrame() {
        #expect(isClose(ShotFit.simulate(shootingSpot, Vec3(0, -1000, 0), pull: 0, at: [1.0 / 240], drag: 0), [Vec3(36, 192 - 1000.0 / 240, 0.75)]))
    }

    @Test("time 0 is the start spot")
    func timeZero() {
        #expect(isClose(ShotFit.simulate(shootingSpot, Vec3(0, -1000, 0), pull: 0, at: [0], drag: 0), [shootingSpot]))
    }

    @Test("gravity pulls a rising puck down")
    func gravity() {
        let rising = ShotFit.simulate(shootingSpot, Vec3(0, -1000, 100), pull: -386.09, at: [0.1], drag: 0)

        #expect(isClose(rising, [Vec3(36, 92, 0.75 + 10 - 0.5 * 386.09 * 0.01)]))
    }

    @Test("air drag slows a 60 mph puck")
    func airDrag() throws {
        let spot = try #require(ShotFit.simulate(shootingSpot, Vec3(0, -1056, 0), pull: 0, at: [0.15], drag: 1.3e-4).first)

        #expect(abs(192 - spot.y - 156.79) <= 0.005)
    }

    @Test("no frame times give an empty path")
    func noTimes() {
        #expect(ShotFit.simulate(shootingSpot, Vec3(0, -1000, 0), pull: 0, at: [], drag: 0).isEmpty)
    }

    @Test("a straight shot crosses the goal line at the right time and spot")
    func straightCrossing() throws {
        let cross = try #require(ShotFit.crossing(shootingSpot, Vec3(0, -1000, 0), 0, t0: 0, until: 0.5, drag: 0))

        #expect(abs(cross.t - 0.192) <= 1e-6)
        #expect(isClose(cross.p, Vec3(36, 0, 0.75), within: 1e-6))
    }

    @Test("a shot 10 seconds into the clip crosses at 10.192 seconds")
    func clipClock() throws {
        let cross = try #require(ShotFit.crossing(shootingSpot, Vec3(0, -1000, 0), 0, t0: 10, until: 0.5, drag: 0))

        #expect(abs(cross.t - 10.192) <= 1e-6)
    }

    @Test("a rising shot crosses 12.83 in up")
    func risingCrossing() throws {
        let cross = try #require(ShotFit.crossing(shootingSpot, Vec3(0, -1000, 100), -386.09, t0: 0, until: 0.5, drag: 0))

        #expect(abs(cross.p.z - 12.8336) <= 0.001)
    }

    @Test("air drag makes the puck reach the line later")
    func dragArrivesLater() throws {
        let cross = try #require(ShotFit.crossing(shootingSpot, Vec3(0, -1000, 0), 0, t0: 0, until: 0.5))

        #expect(abs(cross.t - 0.194416) <= 1e-6)
    }

    @Test("a search that ends at 0.15 seconds finds no crossing")
    func searchTooShort() {
        #expect(ShotFit.crossing(shootingSpot, Vec3(0, -1000, 0), 0, t0: 0, until: 0.15, drag: 0) == nil)
    }

    @Test("a search that ends at 0.193 seconds still finds the crossing")
    func searchJustLongEnough() throws {
        let cross = try #require(ShotFit.crossing(shootingSpot, Vec3(0, -1000, 0), 0, t0: 0, until: 0.193, drag: 0))

        #expect(abs(cross.t - 0.192) <= 1e-6)
    }

    @Test("a puck already past the line has nothing to cross")
    func alreadyPast() {
        #expect(ShotFit.crossing(Vec3(36, -5, 0.75), Vec3(0, -1000, 0), 0, t0: 0, until: 0.5, drag: 0) == nil)
    }

    @Test("a puck heading away from the net never crosses")
    func headingAway() {
        #expect(ShotFit.crossing(shootingSpot, Vec3(0, 1000, 0), 0, t0: 0, until: 0.5, drag: 0) == nil)
    }

    @Test("a sight line crossing the path lands where it crosses")
    func sightLineCrosses() {
        #expect(abs(ShotFit.lineSpot(Vec3(0, 0, 0), Vec3(1, 0, 0), Vec3(5, -10, 0), Vec3(0, 1, 0)) - 5) <= 1e-12)
    }

    @Test("a sight line passing 2 in above the path lands at the closest spot")
    func sightLineMisses() {
        #expect(abs(ShotFit.lineSpot(Vec3(0, 0, 0), Vec3(1, 0, 0), Vec3(5, -10, 2), Vec3(0, 1, 0)) - 5) <= 1e-12)
    }

    @Test("a slanted sight line lands where it crosses")
    func slantedSightLine() {
        #expect(abs(ShotFit.lineSpot(Vec3(0, 0, 0), Vec3(1, 0, 0), Vec3(0, -10, 0), simd_normalize(Vec3(8, 10, 0))) - 8) <= 1e-12)
    }

    @Test("a steady 30 mph slide reads 30 mph")
    func steadySlide() throws {
        let slide = try #require(ShotFit.slide(sliding(mph: 30, frames: firstFrames), pose: camera()))

        #expect(abs(slide.mph - 30) <= 0.01)
    }

    @Test("a slide slowing like on concrete reads its starting speed and crosses later")
    func concreteSlide() throws {
        let slide = try #require(ShotFit.slide(sliding(mph: 30, slowing: 116, frames: firstFrames), pose: camera()))

        #expect(abs(slide.mph - 30) <= 0.01)
        #expect(abs(slide.crossT - 0.3795) <= 1e-4)
    }

    @Test("a steady slide crosses in the middle at the right time")
    func slideCrossing() throws {
        let slide = try #require(ShotFit.slide(sliding(mph: 30, frames: firstFrames), pose: camera()))

        #expect(abs(slide.crossT - 0.3636) <= 1e-4)
        #expect(isClose(slide.hit, Vec3(36, 0, 0.5), within: 0.01))
    }

    @Test("an off-center slide crosses 20 in from the left post")
    func offCenterSlide() throws {
        let slide = try #require(ShotFit.slide(sliding(mph: 30, toward: 20, frames: firstFrames), pose: camera()))

        #expect(isClose(slide.hit, Vec3(20, 0, 0.5), within: 0.01))
    }

    @Test("a puck sliding away from the net gives no answer")
    func slidingAway() {
        let coming = sliding(mph: 30, frames: firstFrames)
        let going = zip(coming.reversed(), firstFrames).map { TrackPoint(t: $1, x: $0.x, y: $0.y) }

        #expect(ShotFit.slide(going, pose: camera()) == nil)
    }

    @Test("a puck that stops in the back of the net doesn't change the speed")
    func stopsInTheNet() throws {
        let clean = try #require(ShotFit.flight(shot(mph: 60, aim: lowShot, until: 0).track, pose: camera(), startHeight: 0.75))
        let messy = try #require(ShotFit.flight(stoppedInNet(), pose: camera(), startHeight: 0.75))

        #expect(abs(clean.lineMph - messy.lineMph) <= 0.01)
    }

    @Test("a lob last seen 0.29 seconds before the line still gets a speed")
    func lostLate() {
        let lob = shot(mph: 25, aim: lobShot)

        #expect(ShotFit.flight(lob.track.filter { $0.t <= lob.crossTime - 0.29 }, pose: camera(), startHeight: 0.75) != nil)
    }

    @Test("a lob last seen 0.31 seconds before the line gets no speed")
    func lostEarly() {
        let lob = shot(mph: 25, aim: lobShot)

        #expect(ShotFit.flight(lob.track.filter { $0.t <= lob.crossTime - 0.31 }, pose: camera(), startHeight: 0.75) == nil)
    }

    @Test("starting the shot 1 in higher reads 1 mph slower")
    func releaseHeight() throws {
        let track = shot(mph: 60, aim: lowShot).track
        let floor = try #require(ShotFit.flight(track, pose: camera(), startHeight: 0.75))
        let higher = try #require(ShotFit.flight(track, pose: camera(), startHeight: 1.75))

        #expect(abs(floor.lineMph - higher.lineMph - 1) <= 0.05)
    }

    @Test("the dot lands within 1 in of where made-up shots hit")
    func dotLandsRight() throws {
        for mph in [40.0, 60, 80] {
            let made = shot(mph: mph, aim: lowShot, frames: dotFrames, drag: 2.5e-4)
            let read = try #require(ShotFit.read(made.track, pose: camera()))

            #expect(simd_distance(read.hit, made.hit) <= 1)
        }
    }

    @Test("corner shots put the dot within 1 in")
    func cornerDots() throws {
        for aim in [Vec3(-34, -192, 40), Vec3(30, -192, 40)] {
            let made = shot(mph: 60, aim: aim, frames: dotFrames, drag: 2.5e-4)
            let read = try #require(ShotFit.read(made.track, pose: camera()))

            #expect(simd_distance(read.hit, made.hit) <= 1)
        }
    }

    @Test("all 19 Nov 16 shots that went in land inside the net")
    func realGoals() throws {
        let goals = try savedShots().filter(\.knownGoal)
        let dots = try goals.map { saved -> Vec2 in
            let pose = try #require(saved.pose)
            return try #require(ShotFit.read(saved.track, pose: pose)).hit
        }

        #expect(goals.count == 19)
        #expect(dots.allSatisfy { (0.0...72).contains($0.x) && (0.0...48).contains($0.y) })
    }

    @Test("9 frames are too few, and so are 7 frames of flight plus frames in the net")
    func nineFrames() {
        let flying = shot(mph: 60, aim: lowShot, until: 0).track
        let inNet = stoppedInNet().filter { $0.t > flying.last!.t }

        #expect(ShotFit.read(Array(shot(mph: 60, aim: lowShot).track.prefix(9)), pose: camera()) == nil)
        #expect(ShotFit.read(Array(flying.prefix(7)) + inNet.prefix(6), pose: camera()) == nil)
    }

    @Test("10 frames are enough")
    func tenFrames() throws {
        let read = try #require(ShotFit.read(Array(shot(mph: 60, aim: lowShot).track.prefix(10)), pose: camera()))

        #expect(abs(read.mph - 60) <= 0.5)
    }

    @Test("made-up shots at 40, 60 and 80 mph read within 0.5 mph")
    func cleanSpeeds() throws {
        for mph in [40.0, 60, 80] {
            #expect(abs(try #require(ShotFit.read(shot(mph: mph, aim: lowShot).track, pose: camera())).mph - mph) <= 0.5)
        }
    }

    @Test("a 100 mph shot reads within 0.5 mph")
    func hardestShot() throws {
        #expect(abs(try #require(ShotFit.read(shot(mph: 100, aim: Vec3(-6, -192, 10)).track, pose: camera())).mph - 100) <= 0.5)
    }

    @Test("a top-shelf shot reads within 0.6 mph")
    func topShelf() throws {
        #expect(abs(try #require(ShotFit.read(shot(mph: 60, aim: Vec3(-6, -192, 50)).track, pose: camera())).mph - 60) <= 0.6)
    }

    @Test("a 25 mph lob reads within 0.7 mph")
    func slowLob() throws {
        #expect(abs(try #require(ShotFit.read(shot(mph: 25, aim: lobShot).track, pose: camera())).mph - 25) <= 0.7)
    }

    @Test("the release is 2 frames before the first clear frame")
    func releaseTime() throws {
        let track = shot(mph: 60, aim: lowShot).track
        let read = try #require(ShotFit.read(track, pose: camera()))

        #expect(abs(read.releaseTime - (track[0].t - 2.0 / 240)) <= 1e-12)
    }

    @Test("dropping 2 of every 6 frames barely changes the speed")
    func droppedFrames() throws {
        let full = shot(mph: 60, aim: lowShot).track
        let gappy = full.enumerated().filter { $0.offset % 6 < 4 }.map(\.element)
        let whole = try #require(ShotFit.read(full, pose: camera()))
        let holes = try #require(ShotFit.read(gappy, pose: camera()))

        #expect(abs(whole.mph - holes.mph) <= 0.2)
    }

    @Test("a puck hidden for 10 frames mid-flight barely changes the speed")
    func hiddenPuck() throws {
        let full = shot(mph: 60, aim: lowShot).track
        let hidden = full.filter { !($0.t > 0.05 && $0.t < 0.09) }
        let whole = try #require(ShotFit.read(full, pose: camera()))
        let gap = try #require(ShotFit.read(hidden, pose: camera()))

        #expect(full.count - hidden.count == 10)
        #expect(abs(whole.mph - gap.mph) <= 0.2)
    }

    @Test("a 60 mph shot from the tester spot, 25 ft to the side on a 5 ft tripod, reads within 0.5 mph")
    func testerSpot() throws {
        let tester = camera(at: Vec3(335, 110.5, 60))
        let read = try #require(ShotFit.read(shot(mph: 60, aim: lowShot, from: tester).track, pose: tester))

        #expect(abs(read.mph - 60) <= 0.5)
    }

    @Test("a clean shot fits with almost no miss, and a path wobbling 1 pixel misses by 1.48")
    func cleanFit() throws {
        let clean = try #require(ShotFit.read(shot(mph: 60, aim: lowShot).track, pose: camera()))
        let wobbly = try #require(ShotFit.read(shot(mph: 60, aim: lowShot, wobble: 1).track, pose: camera()))

        #expect(clean.fitMissPx < 0.01)
        #expect(abs(wobbly.fitMissPx - 1.48) <= 0.01)
    }

    @Test("a 30 mph slide is read as a slide at 30 mph, released at its first frame")
    func slideRead() throws {
        let track = sliding(mph: 30, frames: afterRelease)
        let read = try #require(ShotFit.read(track, pose: camera()))

        #expect(read.slid)
        #expect(abs(read.mph - 30) <= 0.01)
        #expect(read.releaseTime == track[0].t)
    }

    @Test("a slide slowing like on concrete reads within 0.1 mph")
    func concreteSlideRead() throws {
        #expect(abs(try #require(ShotFit.read(sliding(mph: 30, slowing: 116, frames: afterRelease), pose: camera())).mph - 30) <= 0.1)
    }

    @Test("a puck that rises 0.5 in is read as a slide")
    func barelyLifts() throws {
        #expect(try #require(ShotFit.read(rising(0.5).track, pose: camera())).slid)
    }

    @Test("a puck that rises 1.5 in is read as a shot")
    func lifts() throws {
        let read = try #require(ShotFit.read(rising(1.5).track, pose: camera()))

        #expect(!read.slid)
        #expect(abs(read.mph - 80) <= 0.5)
    }

    @Test("the 20 Nov 16 shots miss the radar by 2.55 mph or less on average")
    func matchesRadar() throws {
        let shots = try savedShots()
        let misses = try shots.map { saved -> Double in
            let pose = try #require(saved.pose)
            return abs(try #require(ShotFit.read(saved.track, pose: pose)).mph - saved.radar)
        }

        #expect(shots.count == 20)
        #expect(misses.reduce(0, +) / Double(misses.count) <= 2.55)
    }
}

private let iPhone = Lens(zoom: 1470.2, centerX: 960, centerY: 540)
private let shootingSpot = Vec3(36, 192, 0.75)
private let lowShot = Vec3(-6, -192, 16), lobShot = Vec3(-6, -192, 46)
private let firstFrames = (0..<48).map { Double($0) / 240 }
private let afterRelease = (2..<140).map { Double($0) / 240 }
private let dotFrames = (4..<140).map { Double($0) / 240 }

private struct MadeUpShot {
    let track: [TrackPoint], hit: Vec2, crossTime: Double
}

private struct SavedShot: Decodable {
    let clip: String, radar: Double, knownGoal: Bool, corners: [[Double]], points: [[Double]]

    var track: [TrackPoint] { points.map { TrackPoint(t: $0[0], x: $0[1], y: $0[2]) } }
    var pose: CameraPose? { CameraPose(corners: corners.map { Vec2($0[0], $0[1]) }, lens: iPhone) }
}

private func camera(at spot: Vec3 = Vec3(263, 115, 61.5)) -> CameraPose {
    let forward = simd_normalize(Vec3(36, 60, 20) - spot)
    let level = simd_normalize(Vec3(-forward.y, forward.x, 0))
    let down = simd_normalize(Vec3(0, 0, -1) + forward.z * forward)
    return CameraPose(position: spot, toCamera: simd_double3x3(rows: [level, down, forward]), lens: iPhone)
}

private func shot(mph: Double, aim: Vec3, frames: [Double] = afterRelease, drag: Double = 1.3e-4, until depth: Double = 6,
                  wobble: Double = 0, from phone: CameraPose = camera()) -> MadeUpShot {
    let step = 1e-5
    var spot = shootingSpot, velocity = simd_normalize(aim) * mph * 17.6, time = 0.0
    var next = 0, track: [TrackPoint] = [], hit = Vec2(0, 0), crossTime = 0.0
    while spot.y > -depth && time < 1 {
        if next < frames.count, time >= frames[next] {
            let pixel = phone.pixel(of: spot), shift = wobble * (next % 2 == 0 ? 1 : -1)
            track.append(TrackPoint(t: time, x: pixel.x + shift, y: pixel.y + shift))
            next += 1
        }
        let before = spot
        velocity += step * (Vec3(0, 0, -386.09) - drag * simd_length(velocity) * velocity)
        spot += step * velocity
        time += step
        if before.y > 0, spot.y <= 0 {
            hit = Vec2(spot.x, spot.z)
            crossTime = time
        }
    }
    return MadeUpShot(track: track, hit: hit, crossTime: crossTime)
}

private func stoppedInNet() -> [TrackPoint] {
    let intoNet = shot(mph: 60, aim: lowShot, until: 20).track
    let resting = intoNet.last!
    return intoNet + (1...18).map { TrackPoint(t: resting.t + Double($0) / 240, x: resting.x, y: resting.y) }
}

private func rising(_ inches: Double) -> MadeUpShot {
    shot(mph: 80, aim: Vec3(0, -1408, (2 * 386.09 * inches).squareRoot()))
}

private func sliding(mph: Double, toward across: Double = 36, slowing: Double = 0, frames: [Double]) -> [TrackPoint] {
    let start = Vec3(36, 192, 0.5), direction = simd_normalize(Vec3(across - 36, -192, 0)), speed = mph * 17.6
    return frames.compactMap { time in
        guard speed - slowing * time > 0 else { return nil }
        let spot = start + direction * (speed * time - 0.5 * slowing * time * time)
        guard spot.y > -6 else { return nil }
        let pixel = camera().pixel(of: spot)
        return TrackPoint(t: time, x: pixel.x, y: pixel.y)
    }
}

private func savedShots() throws -> [SavedShot] {
    let url = try #require(Bundle.module.url(forResource: "nov16-shots", withExtension: "json", subdirectory: "Resources"))
    return try JSONDecoder().decode([SavedShot].self, from: Data(contentsOf: url))
}

private func isClose(_ found: [Vec3], _ answer: [Vec3], within tolerance: Double = 1e-9) -> Bool {
    found.count == answer.count && zip(found, answer).allSatisfy { simd_distance($0, $1) <= tolerance }
}

private func isClose(_ found: Vec3, _ answer: Vec3, within tolerance: Double) -> Bool {
    simd_distance(found, answer) <= tolerance
}
