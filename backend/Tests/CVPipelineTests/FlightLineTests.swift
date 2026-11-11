import Testing
import CoreGraphics
@testable import CVPipeline

// Builds made-up frames for a puck flying in a straight line at a steady speed, starting at (100, 500).
// `ticks` says which 1/240-second slot each frame lands on, and `missing` lists frames where the puck wasn't caught.
// `extras` adds the same junk dots to every frame.
func makeFlight(velocity: CGVector, ticks: [Int] = Array(0..<20), missing: Set<Int> = [], extras: [CGPoint] = [])
    -> [(seconds: Double, points: [CGPoint])] {
    return ticks.enumerated().map { k, tick in
        let t = Double(tick) / 240
        let puck = CGPoint(x: 100 + velocity.dx * t, y: 500 + velocity.dy * t)
        return (t, (missing.contains(k) ? [] : [puck]) + extras)
    }
}


@Suite("FlightLine")
struct FlightLineTests {

    /*
    - A perfect shot: 20 frames, the puck moving 1,000 pixels per second straight across
    - This test will expect about 1,000 pixels per second, within 1%
    */
    @Test("a clean shot reads its speed")
    func cleanShot() throws {
        let frames = makeFlight(velocity: CGVector(dx: 1000, dy: 0))

        let speed = try #require(FlightLine().pixelsPerSecond(frames: frames))

        #expect(abs(speed - 1000) <= 10)
    }

    /*
    - The same shot, but the puck wasn't caught in every other frame
    - This test will expect about 1,000 pixels per second, within 1%
    */
    @Test("missing catches don't change the speed")
    func missingCatches() throws {
        let frames = makeFlight(velocity: CGVector(dx: 1000, dy: 0), missing: Set(stride(from: 1, to: 20, by: 2)))

        let speed = try #require(FlightLine().pixelsPerSecond(frames: frames))

        #expect(abs(speed - 1000) <= 10)
    }

    /*
    - The same shot, but the phone skipped frames, so some gaps are 3 times longer
    - This test will expect about 1,000 pixels per second, within 1%, from the real times
    */
    @Test("skipped frames use the real times")
    func skippedFrames() throws {
        let frames = makeFlight(velocity: CGVector(dx: 1000, dy: 0), ticks: [0, 1, 2, 5, 6, 7, 10, 11, 12, 15, 16, 17, 20, 21, 22])

        let speed = try #require(FlightLine().pixelsPerSecond(frames: frames))

        #expect(abs(speed - 1000) <= 10)
    }

    /*
    - The same shot, plus 3 junk dots that sit still in every frame, like lights or fence specks
    - This test will expect about 1,000 pixels per second, within 1%, ignoring the junk
    */
    @Test("still specks are ignored")
    func stillSpecksIgnored() throws {
        let specks = [CGPoint(x: 300, y: 200), CGPoint(x: 900, y: 800), CGPoint(x: 1500, y: 300)]
        let frames = makeFlight(velocity: CGVector(dx: 1000, dy: 0), extras: specks)

        let speed = try #require(FlightLine().pixelsPerSecond(frames: frames))

        #expect(abs(speed - 1000) <= 10)
    }

    /*
    - The same shot, plus a second puck sitting still right next to the shooting spot
    - This test will expect about 1,000 pixels per second, within 1%, ignoring the resting puck
    */
    @Test("a second puck at rest is ignored")
    func restingPuckIgnored() throws {
        let frames = makeFlight(velocity: CGVector(dx: 1000, dy: 0), extras: [CGPoint(x: 110, y: 520)])

        let speed = try #require(FlightLine().pixelsPerSecond(frames: frames))

        #expect(abs(speed - 1000) <= 10)
    }

    /*
    - The same shot, plus one-off junk dots scattered off the path in a few frames
    - This test will expect about 1,000 pixels per second, within 1%, ignoring the junk
    */
    @Test("random junk dots are ignored")
    func randomJunkIgnored() throws {
        var frames = makeFlight(velocity: CGVector(dx: 1000, dy: 0))
        frames[3].points.append(CGPoint(x: 700, y: 900))
        frames[8].points.append(CGPoint(x: 50, y: 100))
        frames[12].points.append(CGPoint(x: 1200, y: 650))
        frames[17].points.append(CGPoint(x: 400, y: 300))

        let speed = try #require(FlightLine().pixelsPerSecond(frames: frames))

        #expect(abs(speed - 1000) <= 10)
    }

    /*
    - A slanted shot: 600 pixels per second across and 800 up, which is 1,000 along the slant
    - This test will expect about 1,000 pixels per second, within 1%
    */
    @Test("a slanted shot measures the slanted distance")
    func slantedShot() throws {
        let frames = makeFlight(velocity: CGVector(dx: 600, dy: 800))

        let speed = try #require(FlightLine().pixelsPerSecond(frames: frames))

        #expect(abs(speed - 1000) <= 10)
    }

    /*
    - Nothing moves: only dots that sit still in every frame
    - This test will expect no speed at all
    */
    @Test("no shot reads nothing")
    func noShot() {
        let still = [CGPoint(x: 100, y: 500), CGPoint(x: 900, y: 800)]
        let frames = (0..<20).map { (seconds: Double($0) / 240, points: still) }

        #expect(FlightLine().pixelsPerSecond(frames: frames) == nil)
    }
}
