import Testing
import Foundation
import CoreGraphics
import ImageIO
import simd
@testable import CVPipeline

/*
Net coordinates, in inches: x runs along the goal line from the left post (0) to the right post (72),
y runs out of the goal toward the shooter (the goal line is y = 0), z runs up from the ice.
A puck is 3 in across, so the whole puck is over the line once its middle is 1.5 in past it (y = -1.5).
ShotFlight gets the puck's spot in each frame from the clack on (PuckLinker), each frame's real time (slow-mo skips
frames now and then), when the puck left the stick (ReleaseFinder, on the same clock as the frame times), and the
camera's place (CameraPose). It works out where the puck left the stick, how fast it left (from the 20 frames right
after the release), and the exact moment the whole puck is over the line and where.
*/
@Suite("ShotFlight")
struct ShotFlightTests {

    /*
    - A pretend puck leaves the ice at (20, 192, 0) and flies in a straight line at 50 mph to a spot 50 in across
      and 30 in up on the net, filmed at 240 frames a second by a pretend phone
    - ShotFlight should find where the whole puck crossed within 1 inch, the distance it flew within 1 inch,
      and the moment within a thousandth of a second
    */
    @Test("finds where and when a straight shot crossed")
    func straightShot() throws {
        let shot = PretendShot(from: SIMD3(20, 192, 0), toward: SIMD3(50, 0, 30), mph: 50, gravity: false)

        let flight = try #require(shot.flight())

        #expect(simd_distance(flight.crossingSpot, shot.wholePuckOver.spot) <= 1)
        #expect(abs(flight.distance - shot.wholePuckOver.distance) <= 1)
        #expect(abs(flight.crossingTime - shot.wholePuckOver.time) <= 0.001)
    }

    /*
    - Same, but the puck is shot upward and gravity pulls it back down, so it flies in an arc like a real shot
    - ShotFlight should still find the crossing spot within 1 inch and the moment within a thousandth of a second
    */
    @Test("finds where and when a rising shot crossed")
    func risingShot() throws {
        let shot = PretendShot(from: SIMD3(20, 192, 0), toward: SIMD3(50, 0, 40), mph: 45, gravity: true)

        let flight = try #require(shot.flight())

        #expect(simd_distance(flight.crossingSpot, shot.wholePuckOver.spot) <= 1)
        #expect(abs(flight.crossingTime - shot.wholePuckOver.time) <= 0.001)
    }

    /*
    - The straight shot again; the front of the puck reaches the line about 3 in (a few thousandths of a second)
      before the whole puck is over
    - The crossing moment should be when the back of the puck passes the line, not the front
    */
    @Test("counts the moment the whole puck is over the line")
    func wholePuck() throws {
        let shot = PretendShot(from: SIMD3(20, 192, 0), toward: SIMD3(50, 0, 30), mph: 50, gravity: false)

        let flight = try #require(shot.flight())

        #expect(abs(flight.crossingTime - shot.wholePuckOver.time) <= 0.001)
        #expect(abs(flight.crossingTime - shot.frontReachesLine) > 0.003)
    }

    /*
    - A puck that's last seen 60 in in front of the goal line, then never again (it stopped, or got blocked)
    - It never reached the line, so ShotFlight should say it didn't cross (nil) instead of guessing
    */
    @Test("says so when the puck never reaches the line")
    func neverCrosses() {
        let shot = PretendShot(from: SIMD3(20, 192, 0), toward: SIMD3(50, 0, 30), mph: 50, gravity: false)

        #expect(shot.flight(seenUntilInFront: 60) == nil)
    }

    /*
    - The straight shot again, but the video skips 2 frames out of every 10 (like iPhone slow-mo does)
    - Using each frame's real time, ShotFlight should still find the crossing spot within 1 inch
      and the moment within a thousandth of a second
    */
    @Test("finds the crossing when the video skips frames")
    func skippedFrames() throws {
        let shot = PretendShot(from: SIMD3(20, 192, 0), toward: SIMD3(50, 0, 30), mph: 50, gravity: false)

        let flight = try #require(shot.flight(skipping: true))

        #expect(simd_distance(flight.crossingSpot, shot.wholePuckOver.spot) <= 1)
        #expect(abs(flight.crossingTime - shot.wholePuckOver.time) <= 0.001)
    }

    /*
    - Like Wali's real shots: for 8 frames after the clack the blade drags the puck 12 in along the ice, then at frame 8
      it leaves the stick and flies the straight 50 mph shot; ShotFlight is told the release is at frame 8
    - The clock should start at frame 8: the time from leaving the stick to the whole puck being over the line within
      a thousandth of a second, and the crossing spot within 1 inch, without the dragged frames throwing it off
    */
    @Test("starts the clock at the release")
    func clockStartsAtTheRelease() throws {
        let shot = PretendShot(from: SIMD3(20, 192, 0), toward: SIMD3(50, 0, 30), mph: 50, gravity: false)

        let flight = try #require(shot.flight(draggedFrames: 8))

        #expect(abs(flight.releaseTime - 8.0 / 240) <= 0.0001)
        #expect(abs(flight.flightTime - shot.wholePuckOver.time) <= 0.001)
        #expect(simd_distance(flight.crossingSpot, shot.wholePuckOver.spot) <= 1)
    }

    /*
    - The same dragged shot: the puck sat 12 in away at the clack, and left the stick at (20, 192, 0)
    - The distance should be measured from where it left the stick (within 1 inch), not from where it sat at the clack
    */
    @Test("measures the distance from where the puck left the stick")
    func distanceFromTheRelease() throws {
        let shot = PretendShot(from: SIMD3(20, 192, 0), toward: SIMD3(50, 0, 30), mph: 50, gravity: false)

        let flight = try #require(shot.flight(draggedFrames: 8))

        #expect(abs(flight.distance - shot.wholePuckOver.distance) <= 1, "flew \(flight.distance) in")
    }

    /*
    - A pretend puck leaves the stick at 50 mph and slows down on the way to the net (pulled back 600 in/s every second)
    - The release speed should be how fast it left the stick (within 1.5 mph of 50), and faster than its average speed
      all the way to the net
    */
    @Test("reads the speed the puck left the stick at, not its average")
    func releaseSpeed() throws {
        let shot = PretendShot(from: SIMD3(20, 192, 0), toward: SIMD3(50, 0, 30), mph: 50, gravity: false, slowing: 600)

        let flight = try #require(shot.flight())

        #expect(abs(flight.releaseMph - 50) <= 1.5, "read \(flight.releaseMph) mph")
        let average = shot.wholePuckOver.distance / shot.wholePuckOver.time / 17.6   // its real average speed to the line
        #expect(flight.releaseMph > average, "release \(flight.releaseMph) mph, real average \(average) mph")
    }

    /*
    - The straight 50 mph shot, but the video skips 2 frames out of every 10, some of them inside the 20 frames after
      the release
    - The release speed should still be 50 mph (within half a mph), using each frame's real time
    */
    @Test("reads the release speed when the video skips frames")
    func releaseSpeedSkippedFrames() throws {
        let shot = PretendShot(from: SIMD3(20, 192, 0), toward: SIMD3(50, 0, 30), mph: 50, gravity: false)

        let flight = try #require(shot.flight(skipping: true))

        #expect(abs(flight.releaseMph - 50) <= 0.5, "read \(flight.releaseMph) mph")
    }

    /*
    - Wali's first shot in the 43mph-54mph clip: puck model boxes from the clack on, linked by PuckLinker,
      starting at the puck Wali clicked at the clack; camera placed from the net (NetCornerFinder + CameraPose)
    - The puck leaves the stick at frame 13 (checked by Wali's eye, and what ReleaseFinder finds)
    - ShotFlight should find a crossing a tenth to four tenths of a second after the clack, near the net, and the
      release speed should be within 5 mph of 48.6, the speed measured from the puck's own 3-inch size in the frames
      after the release (no camera math). The radar read 43, but it reads low when the shot isn't straight at it.
    */
    @Test("finds the crossing in a real shot")
    func realShot() async throws {
        let clip = rinkClips.appendingPathComponent("1x-measured/43mph-54mph.MOV")
        let clack = 8.401 - 0.0175
        let frames = try await VideoFrameExtractor().frames(from: clip, between: clack, and: clack + 0.4)
        let (pose, lens) = try placeCamera("43mph-54mph")
        let startPixel = CGPoint(x: 196, y: 913)

        let detector = PuckDetector()
        let times = frames.map { $0.seconds - frames[0].seconds }
        let path = PuckLinker().path(from: startPixel, times: times) { i, spot in detector.pucks(in: frames[i].image, near: spot) }

        let flight = try #require(ShotFlight(path: path, times: times, releaseTime: times[12], pose: pose, lens: lens))

        #expect(flight.crossingTime >= 0.1 && flight.crossingTime <= 0.4, "crossed \(flight.crossingTime) s after the clack")
        #expect(flight.crossingSpot.x >= -30 && flight.crossingSpot.x <= 102, "crossed \(flight.crossingSpot.x) in across")
        #expect(flight.crossingSpot.y >= 0 && flight.crossingSpot.y <= 70, "crossed \(flight.crossingSpot.y) in up")
        #expect(abs(flight.releaseMph - 48.6) <= 5, "read \(flight.releaseMph) mph")
    }
}

// A typical iPhone 1x camera (26 mm equivalent) filming 1920 px wide.
private let iPhoneLens = LensInfo(width: 1920, height: 1080, centerX: 960, centerY: 540, zoom: 1920.0 * 26 / 36)
private let gravityPull = 386.1   // inches per second, every second

// A pretend phone (233 in in front of the goal line, 30 in left of the left post, 61.5 in up) filming a pretend shot.
private struct PretendShot {
    let start: SIMD3<Double>
    let velocity: SIMD3<Double>   // inches per second as it leaves the stick
    let pull: Double              // downward pull on the puck (0 for a straight shot)
    let slowing: Double           // how much it slows down along its path, inches per second every second (0 = steady)
    let phone = PretendPhone(at: SIMD3(-30, 233, 61.5), aimedAt: SIMD3(60, 0, 24))

    init(from start: SIMD3<Double>, toward target: SIMD3<Double>, mph: Double, gravity: Bool, slowing: Double = 0) {
        self.start = start
        self.slowing = slowing
        pull = gravity ? gravityPull : 0
        let speed = mph * 17.6   // 1 mph = 17.6 inches per second
        // Aim so the puck's middle reaches `target` on the goal line, even with gravity pulling it down on the way.
        let straight = simd_normalize(target - start) * speed
        let time = (start.y - target.y) / -straight.y
        velocity = SIMD3(straight.x, straight.y, straight.z + 0.5 * pull * time)
    }

    // How far along its path it's gone by `t`, in "seconds at the starting speed" (just `t` when it doesn't slow down).
    private func along(_ t: Double) -> Double { t - 0.5 * slowing / simd_length(velocity) * t * t }

    func position(at t: Double) -> SIMD3<Double> { start + velocity * along(t) + SIMD3(0, 0, -0.5 * pull * t * t) }

    // When the middle of the puck is `y` in from the goal line (it only moves toward the net).
    func time(atY y: Double) -> Double {
        let a = (y - start.y) / velocity.y, k = slowing / simd_length(velocity)
        return k == 0 ? a : (1 - (1 - 2 * k * a).squareRoot()) / k
    }

    var wholePuckOver: (time: Double, spot: SIMD2<Double>, distance: Double) {
        let t = time(atY: -1.5), p = position(at: t)
        return (t, SIMD2(p.x, p.z), simd_distance(p, start))
    }
    var frontReachesLine: Double { time(atY: 1.5) }

    // ShotFlight on this shot filmed at 240 frames a second, until 5 frames after the whole puck is over the line,
    // or only until the puck is `seenUntilInFront` inches in front of the line. `skipping` drops 2 frames out of every 10
    // the way iPhone slow-mo does, so the frames aren't evenly spaced.
    // `draggedFrames`: for that many frames after the clack the blade drags the puck 12 in along the ice to `start`,
    // then it leaves the stick; ShotFlight is told the release frame. With 0, the puck leaves the stick at the clack.
    func flight(seenUntilInFront cutoff: Double? = nil, skipping: Bool = false, draggedFrames: Int = 0) -> ShotFlight? {
        let release = Double(draggedFrames) / 240
        let frames = (0..<(Int((wholePuckOver.time + release) * 240) + 6)).filter { !skipping || ($0 % 10 != 8 && $0 % 10 != 9) }
        let times = frames.map { Double($0) / 240 }
        let path: [CGPoint?] = times.map { t in
            let p = t < release ? start + SIMD3(-12, 0, 0) * (1 - t / release) : position(at: t - release)
            if let cutoff, p.y < cutoff { return nil }
            return phone.picture(of: p)
        }
        let corners = [SIMD3(0.0, 0, 48), SIMD3(72.0, 0, 48), SIMD3(72.0, 0, 0), SIMD3(0.0, 0, 0)].map(phone.picture(of:))
        guard let pose = CameraPose(corners: corners, lens: iPhoneLens) else { return nil }
        return ShotFlight(path: path, times: times, releaseTime: release, pose: pose, lens: iPhoneLens)
    }
}

// A perfect pinhole camera at a known spot, aimed at a known point, with no tilt to the side.
private struct PretendPhone {
    let position: SIMD3<Double>
    let forward: SIMD3<Double>
    let right: SIMD3<Double>
    let down: SIMD3<Double>

    init(at position: SIMD3<Double>, aimedAt target: SIMD3<Double>) {
        self.position = position
        forward = simd_normalize(target - position)
        right = simd_normalize(simd_cross(SIMD3(0, 0, 1), forward))
        down = simd_cross(right, forward)
    }

    func picture(of p: SIMD3<Double>) -> CGPoint {
        let d = p - position
        let (x, y, z) = (simd_dot(d, right), simd_dot(d, down), simd_dot(d, forward))
        return CGPoint(x: iPhoneLens.centerX + iPhoneLens.zoom * x / z, y: iPhoneLens.centerY + iPhoneLens.zoom * y / z)
    }
}

// Wali's inside-corner clicks for the newest clips, used as taps for NetCornerFinder.
private struct ClipNet: Decodable {
    struct Spot: Decodable { let x: Double; let y: Double }
    struct Net: Decodable {
        let leftTop: Spot, rightTop: Spot, rightBottom: Spot, leftBottom: Spot
        var corners: [CGPoint] { [leftTop, rightTop, rightBottom, leftBottom].map { CGPoint(x: $0.x, y: $0.y) } }
    }
    let clip: String
    let net: Net
}

private let rinkClips = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .appendingPathComponent("videos/rink-clips")

// Finds the camera's place for one newest clip: NetCornerFinder on the saved frame + SAM 3 mask, then CameraPose.
private func placeCamera(_ name: String) throws -> (CameraPose, LensInfo) {
    let nets = try JSONDecoder().decode([ClipNet].self, from: Data(contentsOf: rinkClips.appendingPathComponent("net-outline.json")))
    let net = try #require(nets.first { $0.clip.contains(name) })
    func image(_ path: String) throws -> CGImage {
        let source = try #require(CGImageSourceCreateWithURL(rinkClips.appendingPathComponent(path) as CFURL, nil))
        return try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
    }
    let mask = try #require(FrameMask(image: try image("sam3-masks/measured-\(name).png")))
    let corners = try NetCornerFinder().find(in: try image("net-frames/measured-\(name).jpg"), taps: net.net.corners, mask: mask)
        .corners.map { try #require($0) }
    return (try #require(CameraPose(corners: corners, lens: iPhoneLens)), iPhoneLens)
}
